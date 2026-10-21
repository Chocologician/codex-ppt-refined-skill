# 接口与命令行后备操作

仅在后备方案已选定后使用；后端选择见[选择规则](backend-selection.md)，配置问题按需读[配置说明](image-model-configuration.md)。skill_root 指技能入口所在目录。

## 运行环境

需要时使用实际可用的 Python 执行：

    python {skill_root}/scripts/run_skill.py bootstrap

若共享运行环境已存在且依赖可用，不重复安装。脚本自动加载 .env；出现真实配置错误后再排查。系统、运行目录与解释器位置通过实际环境查找，不把示例中的 Unix 路径套在 Windows 上。

后续依赖图片库或接口库的操作使用统一入口，它会选择 bootstrap 创建的共享解释器，不能仍用未安装依赖的任意系统 Python。

统一入口仅为本次子进程启用UTF-8日志输出，避免Windows默认编码无法输出上游脚本的符号；不更改系统或父进程配置。

## 生成与编辑

    python {skill_root}/scripts/run_skill.py image-gen generate --model gpt-image-2.5-flare --prompt-file {prompt_file} --size 2560x1440 --quality medium --out {output_path}

    python {skill_root}/scripts/run_skill.py image-gen edit --image {source_image} --prompt "具体编辑要求" --out {new_output_path}

模型名和参数能力以实际服务为准。上游脚本默认横版16:9、2560x1440、中等质量；需要更高清晰度时核查后端支持并检查实际输出，不能只凭参数宣称已达到要求。

从 prompts/slide_XX.json 调用时使用其 prompt 字段，但先检查 input_images 与 requires_context_images。非空图片输入不能被只有文字的 generate 命令取代；应使用能够传入全部素材的参考图/编辑路径。缺少路径时报阻塞，不生成替代证据。

## 透明背景

根据具体模型和适配器验证。某些兼容接口支持 background=transparent，某些适配器不转发该参数；JPEG不能保留透明。不要因模型名字相近承诺相同能力。工具不支持原生透明时，按已批准方案使用纯色背景与 remove_chroma_key.py，并检查边缘。未经要求不换模型。

## 诊断与组装

    python {skill_root}/scripts/codex_ppt_runtime.py doctor --check-api

只在真实后备接口故障排查时调用接口诊断，避免为静态检查发起付费请求。组装支持16:9与4:3，默认按用户任务选择横版16:9，详见[项目与组装](project-assembly-and-reporting.md)。
