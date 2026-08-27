# runpod-templates

RunPod で AI 環境を起動するためのテンプレート集です。

この repo には公開利用者向けの配布物だけを置きます。作業メモ、検証ログ、API key、template ID、pod ID は含めません。

## Templates

wan22 / acestep15xl は CUDA 12.8 image を推奨、CUDA 13.0 image を選択肢として用意しています。
minimax-h3 は `int8_convrot` カーネルのため CUDA 13.0 image を推奨します。

| Name | Path | Use case | UI | Ports |
|---|---|---|---|---|
| `ComfyUI-Wan2.2-cuda12.8-v3-FreeCraftLog` | `templates/wan22/` | Wan2.2 動画生成用 ComfyUI 環境 | ComfyUI | `8188/http`, `22/tcp` |
| `ComfyUI-ACE-Step1.5XL-cuda12.8-v3-FreeCraftLog` | `templates/acestep15xl/` | ACE-Step 1.5 XL 音楽生成用 ComfyUI 環境 | ComfyUI | `8188/http`, `22/tcp` |
| `ComfyUI-MiniMaxH3-R2V-cuda130-FreeCraftLog` | `templates/minimax-h3/` | MiniMax H3 Ref2VA（映像＋音声）用 ComfyUI 環境。**地域制約あり** | ComfyUI | `8188/http`, `22/tcp` |

## Deploy Links

### v3.0.0（推奨）

| Template | CUDA | RunPod deploy link |
|---|---|---|
| `ComfyUI-Wan2.2-cuda12.8-v3-FreeCraftLog` | 12.8 | <https://console.runpod.io/deploy?template=tfcpp13sns&ref=zc2sdxqc> |
| `ComfyUI-Wan2.2-cuda130-v3-FreeCraftLog` | 13.0 | <https://console.runpod.io/deploy?template=429co6ch6n&ref=zc2sdxqc> |
| `ComfyUI-ACE-Step1.5XL-cuda12.8-v3-FreeCraftLog` | 12.8 | <https://console.runpod.io/deploy?template=02uvewl5gg&ref=zc2sdxqc> |
| `ComfyUI-ACE-Step1.5XL-cuda130-v3-FreeCraftLog` | 13.0 | <https://console.runpod.io/deploy?template=lebbkuupd8&ref=zc2sdxqc> |

**CUDA 12.8 のほうを推奨します。** 12.8 image は host に `cuda>=12.8` しか要求しないため、
12.8 host でも 13.0 host でも起動します。13.0 image は `cuda>=13.0` を要求するので 13.0 host が必要です。

### v1.0.0（据え置き）

CUDA 12.4 版です。`v3.0.0` で 12.4 は廃止しましたが、既存の利用者と公開記事の導線のため残しています。

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
現在の安定版は `v3.0.0` です。

`v3.0.0`（wan22 / acestep15xl のみ変更。minimax-h3 は v2.1.0 と同じ内容）:

- **`v2.0.0` / `v2.1.0` の wan22 / acestep15xl は ComfyUI が起動しません。使わないでください。**
  `requirements.txt` の `comfy-kitchen>=0.2.8` が浮動指定だったため、`COMFYUI_REF` を固定していても
  ビルド日によって入る版が変わり、8月ビルドの `comfy-kitchen` が PyTorch 2.4.1 と非互換になりました。
  import 時に `ValueError: Parameter kernel_size has unsupported type list[int]` で落ちます。
- **ComfyUI を `v0.19.3` から `v0.32.0` に更新。** `v0.32.0` の `requirements.txt` は
  `comfy-kitchen` / `comfy-aimdo` を `==` で固定しているため、この浮動指定の問題ごと解消します。
  13 マイナーバージョン分の差があるため、既存ワークフローがノード API 変更で壊れる可能性があります。
- **CUDA 12.4 image を廃止。** `comfy-kitchen` が PyTorch 2.5 以上を要求するためです。
- **CUDA 12.8 image を既定にした。** どちらのベースイメージも `NVIDIA_REQUIRE_CUDA` を持っており、
  `cuda12.8` は host に `cuda>=12.8`、`cuda13.0` は `cuda>=13.0` を要求します。
  **`cuda12.8` のほうが起動できる host が広い**（12.8 host と 13.0 host の両方）ため、こちらを既定にしています。
  `cuda13.0` は最新 CUDA を使いたい場合の選択肢です。
- **ベースイメージの PyTorch を constraints で固定。** ComfyUI の `requirements.txt` が torch を
  裸で要求するため、pip が PyPI の既定ビルドで置き換えうる経路を塞ぎました。
- **未参照だった `setup.sh` を wan22 / acestep15xl から削除。**

`v2.1.0`（minimax-h3 のみ変更。wan22 / acestep15xl は v2.0.0 と同じ内容）:

- **Turbo LoRA を既定で取得するようにした。** ワークフロー側で無効にしていても、
  `LoraLoaderModelOnly` がグラフにある限り ComfyUI は `lora_name` を検証するため、
  取得しないと公式テンプレート由来のワークフローが生成時に落ちる。
- **「CUDA 13.0 ホストが必要」の記述を撤回。** forward compatibility が効くため、
  `cudaVersion: 12.8` の Pod でも cuda13.0 版は動作する（実機確認済み）。
- ComfyUI の clone を `--depth 1` にし、pip キャッシュを削除（イメージ縮小）。

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
      runpod-readme.cuda128.md
      runpod-readme.cuda130.md
      start.sh
      template.cuda128.json
      template.cuda130.json
    acestep15xl/
      Dockerfile
      README.md
      runpod-readme.cuda128.md
      runpod-readme.cuda130.md
      start.sh
      template.cuda128.json
      template.cuda130.json
    minimax-h3/
      Dockerfile
      README.md
      start.sh
      template.cuda128.json
      template.cuda130.json
```

`template.json`（CUDA 12.4 版）はどのテンプレートにもありません。`v3.0.0` で CUDA 12.4 を廃止したためです。

`runpod-readme.cuda128.md` / `runpod-readme.cuda130.md` は RunPod console の template README に
貼る用の原稿です。**console の README は API から書き込めない**（`create-template` / `update-template` の
`readme` が反映されない）ため、ここを正として手で貼り付けます。

console で template を public にするには、README を既定のひな形から変えることと、
各ポートにラベルを付けることの両方が必要です。ラベルは `8188/http` を `ComfyUI`、`22/tcp` を `SSH` にします。

`setup.sh` はどのテンプレートにもありません。ComfyUI をイメージに焼き込んだ（`ac47f8f`）あと、
Pod の起動処理は `start.sh` だけが担っています。`setup.sh` は Dockerfile からも template からも
参照されない死にコードだったため削除しました。

## Notes

- モデルファイルはこの repo には含めません。
- 公開運用時は Container image の tag を release tag に固定してください。
- 検証後は想定外の GPU 課金を避けるため、test pod を停止または削除してください。

## License

MIT License
