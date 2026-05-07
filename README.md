# runpod-templates

RunPod で AI 環境を起動するためのテンプレート集です。

この repo には公開利用者向けの配布物だけを置きます。作業メモ、検証ログ、API key、template ID、pod ID は含めません。

## Templates

| Name | Path | Use case | UI | Ports |
|---|---|---|---|---|
| `wan22` | `templates/wan22/` | Wan2.2 動画生成用 ComfyUI 環境 | ComfyUI | `8188/http`, `22/tcp` |
| `acestep15xl` | `templates/acestep15xl/` | ACE-Step 1.5 XL 音楽生成用 ComfyUI 環境 | ComfyUI | `8188/http`, `22/tcp` |
| `acestep15xl-cuda128` | `templates/acestep15xl/` | ACE-Step 1.5 XL 音楽生成用 ComfyUI 環境。RTX 5090 など CUDA 12.8 が必要な GPU 向け | ComfyUI | `8188/http`, `22/tcp` |

## Usage

各テンプレートの設定、環境変数、Start Command はテンプレートごとの README を参照してください。

- [Wan2.2](templates/wan22/README.md)
- [ACE-Step 1.5 XL](templates/acestep15xl/README.md)

## Repository layout

```text
runpod-templates/
  README.md
  templates/
    wan22/
      README.md
      setup.sh
      template.json
    acestep15xl/
      README.md
      setup.sh
      template.json
      template.cuda128.json
```

## Notes

- モデルファイルはこの repo には含めません。
- 安定運用時は Start Command の `RUNPOD_TEMPLATES_REF` を release tag または commit SHA に固定してください。
- 検証後は想定外の GPU 課金を避けるため、test pod を停止または削除してください。

## License

MIT License
