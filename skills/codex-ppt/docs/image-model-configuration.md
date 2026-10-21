# 图片模型与接口配置

仅在已选择接口/命令行后备方案，而且缺少或需要修改配置时阅读。脚本自动读取共享 .env，不手工解析它。

## 何时配置

真实调用报告缺少 OPENAI_API_KEY，出现鉴权、权限、接口地址或模型不可用错误，或用户明确要求修改设置时处理。内置生图可用并满足要求时，不要求用户配置外部服务。

- OPENAI_API_KEY：真实后备调用需要。
- OPENAI_BASE_URL：可选；未设置则按脚本默认官方接口处理，设置后使用指定服务。
- CODEX_PPT_IMAGE_MODEL：可选；当前脚本默认 gpt-image-2.5-flare。模型与能力是否可用以所选服务为准。
- CODEX_PPT_HOME：可选，共享运行目录。

## 命令

使用实际 skill_root 和本机 Python 位置。以下是配置形状，示例不是可用凭据：

    python {skill_root}/scripts/codex_ppt_runtime.py config --api-key "替换为密钥" --model gpt-image-2.5-flare

兼容接口：

    python {skill_root}/scripts/codex_ppt_runtime.py config --api-key "替换为密钥" --base-url "https://example.com/v1" --model "服务支持的模型"

兼容 OpenAI 的地址通常停在 /v1 根路径，不填 /images/generations 或 /images/edits，脚本自行追加端点。

上游 AtlasCloud 适配示例使用 https://api.atlascloud.ai/api/v1/model 和 openai/gpt-image-2。更换模型前核查对应服务文档，不承诺所有路由或能力一致。

配置写入共享运行目录的 .env。上游实现请求使用受限文件权限；系统环境变量优先于文件，单次 --model 优先于 CODEX_PPT_IMAGE_MODEL。不要将真实凭据写入仓库或日志。
