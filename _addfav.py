import glob

FAV = "<link rel=\"icon\" href=\"data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 32 32'%3E%3Crect width='32' height='32' fill='%23ffffff'/%3E%3Cg fill='none' stroke='%23231f20' stroke-width='2' stroke-linejoin='round'%3E%3Cpath d='M16 7 C12 5 8 5 5 6 L5 25 C8 24 12 24 16 26 C20 24 24 24 27 25 L27 6 C24 5 20 5 16 7 Z'/%3E%3Cline x1='16' y1='7' x2='16' y2='26'/%3E%3C/g%3E%3C/svg%3E\">"

done, skipped = [], []
for f in glob.glob("**/*.html", recursive=True):
    s = open(f, encoding="utf-8").read()
    if 'rel="icon"' in s:
        skipped.append(f); continue
    if "</title>" not in s:
        skipped.append(f + " (no title)"); continue
    s = s.replace("</title>", "</title>\n" + FAV, 1)
    open(f, "w", encoding="utf-8").write(s)
    done.append(f)

print("inserted:", len(done))
print("skipped:", len(skipped))
for x in skipped:
    print("  ", x)
