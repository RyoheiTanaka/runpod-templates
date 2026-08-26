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
| `ComfyUI-MiniMaxH3-R2V-cuda128-FreeCraftLog` | `templates/minimax-h3/` | MiniMax H3 Ref2VA（映像＋音声）用 ComfyUI 環境。H100 など CUDA 12.8 以上の GPU 向け。**地域制約あり** | ComfyUI | `8188/http`, `22/tcp` |

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
- [MiniMax H3 (Ref2VA)](templates/minimax-h3/README.md)

MiniMax H3 template は MiniMax H3 Community License の Excluded Territories（EU / 英国 / 韓国 / 米国）で
使用できません。Pod を起動するデータセンターの選択に注意してください。詳細は template の README を参照してください。

## Versioning

公開用の RunPod template は GHCR image tag を release tag に固定します。
現在の安定版は `v2.0.0` です。

`v2.0.0` は既存利用者の挙動が変わるため major を上げています。

- **sshd を起動するようにした。** `CMD` で公式イメージの entrypoint を置き換えているせいで、
  `PUBLIC_KEY` は届いているのに sshd がおらず、**全テンプレートで SSH が繋がらなかった。**
- **`--enable-cors-header "*"` を外した。** ブラウザから別オリジンで叩いていた場合は壊れます。
- `HF_HUB_ENABLE_HF_TRANSFER` を `HF_XET_HIGH_PERFORMANCE` に変更（`hf_transfer` は no-op）。

`v1.0.0` のテンプレートは `v1.0.0-*` の image tag を指しているため、この変更の影響を受けません。
移行するかどうかは利用者の判断に任せ、既存テンプレートはそのまま残します。

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
      Dockerfile
      README.md
      setup.sh
      start.sh
      template.json
      template.cuda128.json
    acestep15xl/
      Dockerfile
      README.md
      setup.sh
      start.sh
      template.json
      template.cuda128.json
    minimax-h3/
      Dockerfile
      README.md
      start.sh
      template.cuda128.json
      template.cuda130.json
```

`minimax-h3` に `template.json`（CUDA 12.4 版）はありません。H100 では CUDA 12.4 が使えないためです。

`minimax-h3` には `setup.sh` がありません。ComfyUI をイメージに焼き込んだ（`ac47f8f`）あと、
Pod の起動処理は `start.sh` だけが担っています。`setup.sh` は Dockerfile からも template からも
参照されない死にコードだったため削除しました。**wan22 / acestep15xl の `setup.sh` も同様に
未参照なので、整理する余地があります。**

## Notes

- モデルファイルはこの repo には含めません。
- 公開運用時は Container image の tag を release tag に固定してください。
- 検証後は想定外の GPU 課金を避けるため、test pod を停止または削除してください。

## License

MIT License
