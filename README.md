# runpod-templates

RunPod で AI 環境を起動するためのテンプレート集です。

この repo には公開利用者向けの配布物だけを置きます。作業メモ、検証ログ、API key、template ID、pod ID は含めません。

## Templates

| Name | Path | Use case | UI | Ports |
|---|---|---|---|---|
| `ComfyUI-Wan2.2-FreeCraftLog` | `templates/wan22/` | Wan2.2 動画生成用 ComfyUI 環境 | ComfyUI | `8188/http`, `22/tcp` |
| `ComfyUI-Wan2.2-cuda12.8-FreeCraftLog` | `templates/wan22/` | Wan2.2 動画生成用 ComfyUI 環境。CUDA 12.8 対応 driver の host 向け | ComfyUI | `8188/http`, `22/tcp` |
| `ComfyUI-ACE-Step1.5XL-FreeCraftLog` | `templates/acestep15xl/` | ACE-Step 1.5 XL 音楽生成用 ComfyUI 環境 | ComfyUI | `8188/http`, `22/tcp` |
| `ComfyUI-ACE-Step1.5XL-cuda12.8-FreeCraftLog` | `templates/acestep15xl/` | ACE-Step 1.5 XL 音楽生成用 ComfyUI 環境。RTX 5090 など CUDA 12.8 が必要な GPU 向け | ComfyUI | `8188/http`, `22/tcp` |

## Deploy Links

| Template | RunPod deploy link |
|---|---|
| `ComfyUI-Wan2.2-FreeCraftLog` | <https://console.runpod.io/deploy?template=soj5tjnbex&ref=zc2sdxqc> |
| `ComfyUI-Wan2.2-cuda12.8-FreeCraftLog` | <https://console.runpod.io/deploy?template=x4ckgbo5gt&ref=zc2sdxqc> |
| `ComfyUI-ACE-Step1.5XL-FreeCraftLog` | <https://console.runpod.io/deploy?template=whhlf8rbip&ref=zc2sdxqc> |
| `ComfyUI-ACE-Step1.5XL-cuda12.8-FreeCraftLog` | <https://console.runpod.io/deploy?template=0obn96ivv6&ref=zc2sdxqc> |

## Usage

各テンプレートの設定、環境変数、Start Command はテンプレートごとの README を参照してください。

- [Wan2.2](templates/wan22/README.md)
- [ACE-Step 1.5 XL](templates/acestep15xl/README.md)

## Versioning

公開用の RunPod template は GHCR image tag を release tag に固定します。
現在の安定版は `v1.0.0` です。

- `main`: 開発・検証用。最新変更を試す場合のみ Pod 起動時に指定します。
- `v1.0.0`: 初回安定版。公開 deploy link と template JSON の既定値です。
- `v1.0.x`: 起動失敗修正、download URL 修正、README 修正などの互換性を壊さない修正。
- `v1.x.0`: variant 追加や環境変数追加など、既存利用者を壊さない機能追加。
- `v2.0.0`: 既定モデル、環境変数名、必要 disk など、既存利用者の挙動が変わる変更。

release tag を切る前に、template JSON、README、RunPod console 側の container image tag が同じ release tag を指していることを確認してください。

## Repository layout

```text
runpod-templates/
  README.md
  templates/
    wan22/
      README.md
      setup.sh
      template.json
      template.cuda128.json
    acestep15xl/
      README.md
      setup.sh
      template.json
      template.cuda128.json
```

## Notes

- モデルファイルはこの repo には含めません。
- 公開運用時は Container image の tag を release tag に固定してください。
- 検証後は想定外の GPU 課金を避けるため、test pod を停止または削除してください。

## License

MIT License
