# Downsizes embedded PNG textures inside a .glb (GLB binary) using .NET WIC.
# baseColor -> $MaxBase, normal/ORM (and anything else) -> $MaxOther. Keeps PNG format
# (no mimeType change). Repacks the BIN chunk and rewrites bufferView offsets/lengths.
# JSON is edited by targeted regex (bufferViews + buffer byteLength) to avoid
# ConvertTo-Json mangling single-element arrays elsewhere in the glTF.
param(
  [Parameter(Mandatory=$true)][string]$In,
  [Parameter(Mandatory=$true)][string]$Out,
  [int]$MaxBase = 1024,
  [int]$MaxOther = 512
)
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

$bytes = [System.IO.File]::ReadAllBytes($In)
$c0len = [BitConverter]::ToUInt32($bytes,12)
$jsonStr = [System.Text.Encoding]::UTF8.GetString($bytes,20,$c0len)
$j = $jsonStr | ConvertFrom-Json
$binChunkOff = 20 + $c0len
$c1len = [BitConverter]::ToUInt32($bytes,$binChunkOff)
$binStart = $binChunkOff + 8
$bin = New-Object byte[] $c1len
[Array]::Copy($bytes,$binStart,$bin,0,$c1len)

# image index -> role (base / normal / orm)
$role = @{}
foreach($m in $j.materials){
  $pbr = $m.pbrMetallicRoughness
  if($pbr -and $pbr.baseColorTexture){ $role[[int]$j.textures[[int]$pbr.baseColorTexture.index].source] = 'base' }
  if($pbr -and $pbr.metallicRoughnessTexture){ $role[[int]$j.textures[[int]$pbr.metallicRoughnessTexture.index].source] = 'orm' }
  if($m.normalTexture){ $role[[int]$j.textures[[int]$m.normalTexture.index].source] = 'normal' }
}
# bufferView index -> image index
$bvImage = @{}
for($i=0; $i -lt $j.images.Count; $i++){ $bvImage[[int]$j.images[$i].bufferView] = $i }

function Resize-Png([byte[]]$data,[int]$max){
  $ms = New-Object System.IO.MemoryStream(,$data)
  $opts = [System.Windows.Media.Imaging.BitmapCreateOptions]::PreservePixelFormat -bor [System.Windows.Media.Imaging.BitmapCreateOptions]::IgnoreColorProfile
  $dec = [System.Windows.Media.Imaging.BitmapDecoder]::Create($ms,$opts,[System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad)
  $frame = $dec.Frames[0]
  $w = $frame.PixelWidth; $h = $frame.PixelHeight
  $scale = [Math]::Min(1.0, $max / [double][Math]::Max($w,$h))
  if($scale -lt 1.0){
    $tb = New-Object System.Windows.Media.Imaging.TransformedBitmap
    $tb.BeginInit(); $tb.Source = $frame
    $tb.Transform = New-Object System.Windows.Media.ScaleTransform($scale,$scale)
    $tb.EndInit(); $src = $tb
  } else { $src = $frame }
  $enc = New-Object System.Windows.Media.Imaging.PngBitmapEncoder
  $enc.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($src))
  $os = New-Object System.IO.MemoryStream
  $enc.Save($os)
  return ,$os.ToArray()
}

# rebuild BIN: copy each bufferView (resize if image), 4-byte aligned, record new bounds
$newBin = New-Object System.IO.MemoryStream
$newBV = @()
for($i=0; $i -lt $j.bufferViews.Count; $i++){
  $bv = $j.bufferViews[$i]
  $off = [int]$bv.byteOffset
  $len = [int]$bv.byteLength
  $slice = New-Object byte[] $len
  [Array]::Copy($bin,$off,$slice,0,$len)
  if($bvImage.ContainsKey($i)){
    $imgIdx = $bvImage[$i]
    $max = if($role[$imgIdx] -eq 'base'){ $MaxBase } else { $MaxOther }
    $before = $slice.Length
    $slice = Resize-Png $slice $max
    Write-Host ("  image[{0}] {1}: {2} -> {3} bytes" -f $imgIdx,$role[$imgIdx],$before,$slice.Length)
  }
  # 4-byte align
  while(($newBin.Length % 4) -ne 0){ $newBin.WriteByte(0) }
  $newOff = [int]$newBin.Length
  $newBin.Write($slice,0,$slice.Length)
  $newBV += [PSCustomObject]@{ idx=$i; byteOffset=$newOff; byteLength=$slice.Length }
}
$newBinBytes = $newBin.ToArray()

# build new bufferViews JSON manually (preserve all original fields, override off/len)
$bvJson = for($i=0; $i -lt $j.bufferViews.Count; $i++){
  $o = $j.bufferViews[$i].PSObject.Copy()
  $o | Add-Member -NotePropertyName byteOffset -NotePropertyValue $newBV[$i].byteOffset -Force
  $o | Add-Member -NotePropertyName byteLength -NotePropertyValue $newBV[$i].byteLength -Force
  $o | ConvertTo-Json -Compress -Depth 5
}
$bvArr = '"bufferViews":[' + ($bvJson -join ',') + ']'

# patch JSON: bufferViews array + single buffer byteLength (literal .Replace, not regex
# replacement, so '$' in JSON can't be misread; match is whitespace-tolerant + verified)
$mBV = [regex]::Match($jsonStr,'"bufferViews"\s*:\s*\[[^\]]*\]')
if(-not $mBV.Success){ throw "bufferViews array not found in JSON" }
$newJson = $jsonStr.Replace($mBV.Value, $bvArr)
$mBuf = [regex]::Match($newJson,'"buffers"\s*:\s*\[[^\]]*\]')
if(-not $mBuf.Success){ throw "buffers array not found in JSON" }
$newJson = $newJson.Replace($mBuf.Value, '"buffers":[{"byteLength":' + $newBinBytes.Length + '}]')

# sanity: every bufferView must fit inside the new buffer
$chk = $newJson | ConvertFrom-Json
$maxEnd = 0; foreach($bv in $chk.bufferViews){ $e=[int]$bv.byteOffset+[int]$bv.byteLength; if($e -gt $maxEnd){$maxEnd=$e} }
if($maxEnd -gt $newBinBytes.Length){ throw "bufferView overruns buffer: $maxEnd > $($newBinBytes.Length)" }
Write-Host ("  JSON patched: bufferViews fit ({0} <= {1})" -f $maxEnd,$newBinBytes.Length)

# assemble GLB. Pad each chunk to a 4-byte boundary WITHOUT array += (which would turn
# the [byte[]] into [object[]] and corrupt BinaryWriter.Write). Write exact bytes.
$jsonBytes = [System.Text.Encoding]::UTF8.GetBytes($newJson)   # byte[]
$jsonPad = (4 - ($jsonBytes.Length % 4)) % 4
$jsonLen = $jsonBytes.Length + $jsonPad
$binPad  = (4 - ($newBinBytes.Length % 4)) % 4
$binLen  = $newBinBytes.Length + $binPad
$total = 12 + 8 + $jsonLen + 8 + $binLen

$outMs = New-Object System.IO.MemoryStream
$bw = New-Object System.IO.BinaryWriter($outMs)
$bw.Write([uint32]0x46546C67); $bw.Write([uint32]2); $bw.Write([uint32]$total)
$bw.Write([uint32]$jsonLen); $bw.Write([uint32]0x4E4F534A)
$bw.Write($jsonBytes); for($k=0;$k -lt $jsonPad;$k++){ $bw.Write([byte]0x20) }
$bw.Write([uint32]$binLen); $bw.Write([uint32]0x004E4942)
$bw.Write($newBinBytes); for($k=0;$k -lt $binPad;$k++){ $bw.Write([byte]0) }
$bw.Flush()
[System.IO.File]::WriteAllBytes($Out, $outMs.ToArray())
$bw.Close()
Write-Host ("DONE: {0:N1} MB -> {1:N1} MB" -f ($bytes.Length/1MB), ((Get-Item $Out).Length/1MB))
