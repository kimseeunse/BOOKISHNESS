# 스크린 책 100프로젝트 — 웹 작업 폴더

## 폴더 구조

```
screen-book/
├── index.html          ← three.js 작업대. 브라우저로 여는 파일.
├── README.md           ← 이 파일.
├── models/             ← GLB 모델을 넣는 곳.
│   └── box.glb         ← 텍스처 입혀진 플럭서스 박스 (완성).
├── hdri/               ← HDRI 환경맵(.hdr)을 넣는 곳. 지금은 비어 있음.
└── textures-source/    ← 박스 텍스처 원본(JPG). 보관용. 안 건드려도 됨.
```

## 여는 방법

GLB를 불러오므로 그냥 더블클릭하면 브라우저 보안에 막힙니다.
로컬 서버가 필요합니다. 둘 중 하나:

1. VS Code → Live Server 확장 설치 → index.html 우클릭 → "Open with Live Server"
2. 터미널에서 이 폴더로 이동 후:  python -m http.server
   그다음 브라우저에서 localhost:8000 접속

## 지금 상태

- box.glb 가 models/ 에 있고, index.html 이 그걸 불러오도록 설정됨.
- 박스가 뜨고, 뚜껑(lid)을 클릭하면 열림.

## 새 오브제 GLB가 나오면

1. GLB를 models/ 폴더에 넣기 (예: models/candle.glb)
2. index.html 의 CONFIG 부분에서 경로 추가/수정

## 화면이 어두울 때

index.html 안에서:
- renderer.toneMappingExposure = 1.0  →  1.5 ~ 1.8 로 올리기
- 또는 .hdr 파일을 hdri/ 에 넣고 CONFIG.hdriURL 에 경로 지정

## HDRI 구하기

Poly Haven (polyhaven.com/hdris) 등에서 무료 .hdr 다운로드.
실내/스튜디오 분위기의 것을 hdri/ 폴더에 넣고
CONFIG.hdriURL = "hdri/파일이름.hdr" 로 지정.
