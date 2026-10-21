---
name: codex-ppt
description: 从资料生成风格统一的图片式演示文稿，或将已认可的稿件推进为逐页校准、可编辑并具有精编原生动画的演示文稿。
metadata:
  openclaw:
    requires:
      bins:
        - python3
    primaryEnv: OPENAI_API_KEY
    envVars:
      - name: OPENAI_API_KEY
        required: false
        description: 接口或命令行后备方案使用的密钥。
      - name: OPENAI_BASE_URL
        required: false
        description: 图片服务的接口根地址。
      - name: CODEX_PPT_IMAGE_MODEL
        required: false
        description: 图片模型名称，当前脚本默认值为 gpt-image-2.5-flare。
      - name: CODEX_PPT_HOME
        required: false
        description: 可选的共享运行目录。
    homepage: https://github.com/ningzimu/codex-ppt-skill
---

# 演示文稿制作与精编动画

## 来源与模式

原有图片式制作流程、生图脚本、风格参考和组装方式来自 [ningzimu/codex-ppt-skill](https://github.com/ningzimu/codex-ppt-skill)，原作者为 ningzimu。本项目新增可编辑重建与精编动画分支，并对操作文档作中文整理；不是上游官方版本。分发时保留 LICENSE 与 NOTICE.md。

先根据任务选择模式：

- 图片式制作：每页是完整生成图片，使用 scripts/assemble_ppt.py 组装。适合接受页面元素不能单独编辑的任务。
- 可编辑与动画：用户要求重建、匹配图片/PDF稿、组件动画或调速时，阅读[动画延伸](docs/editable-refined-animation.md)，从对应阶段进入。不为仅调速重新生成已认可的视觉稿。

下文的生图后端、整页图片、图片任务状态与分工规则仅适用于图片式制作，不禁止可编辑分支使用原生文本、表格和图形。已有授权持续有效，日常细化不重复确认。

## 图片式制作约束

- 各阶段按需阅读对应参考，不一次加载所有文档。
- 按[阶段与进度](docs/workflow-gates-and-progress.md)尊重确认节点；用户已明确授权或要求跳过的节点不重复设置。
- 样张认可并授权全篇后，环境支持子代理时按上游流程分派剩余图片页任务，主代理负责上下文、状态、质检、讲稿和组装。
- 最终 origin_image/slide_XX.png 来自已选择的生图后端；不能用本地绘图、网页截图、原生排版截图或叠字冒充生成图片。该限制不用于原生可编辑分支。
- 后端确认后不因方便而切换；样张的实际生成方法记录到任务并传给每个工作者。
- 分派、结果与阻塞使用状态脚本记录，不以聊天描述代替完成证据。
- 必需工具、素材或分工能力缺失时，报告具体页面、证据与缺失原因，不伪造完成。
- 优先使用当前可调用的内置生图能力；只有能力缺失、后端失败或用户明确要求时使用接口/命令行后备方案。

## 默认流程

需要本地Python依赖时先用 scripts/run_skill.py bootstrap 安装，后续生图、任务状态与组装使用同一入口，避免系统解释器和共享环境混用。原生动画示例不需要图片依赖。

1. 读资料，明确受众、目的、页数、时长、素材和禁用内容。页数按任务选择，不默认添加多余页面。
2. 阅读[大纲、风格与样张](docs/outline-style-and-sample.md)，草拟 outline.md，明确逐页角色和必需素材映射。未获相关授权前不进入下一确认阶段。
3. 用户已有风格参考时先渲染并查看，提取规则；没有明确方向时给少量具体选项。
4. 阅读[后端选择](docs/backend-selection.md)，检查实际工具，说明选择；不从产品名称推断工具可用性。
5. 生成一页有代表性的内容样张，认可后复用其最终文件并记录 sample_generation_method。
6. 按[项目与组装](docs/project-assembly-and-reporting.md)建立目录。明确区分源素材、草稿与最终页图。
7. 按[用户素材](docs/user-supplied-assets.md)准备严格输入。不能把原始图表当成自由改绘的灵感。
8. 按[生成与分工](docs/slide-generation-and-subagents.md)编写完整任务，记录状态并分派；每个工作者只负责一页。
9. 逐页检查中文、内容、素材、裁切与全篇一致性；局部问题用所选后端编辑，严重错误重生成。
10. 写与最终大纲对应的 speech.md，确认非样张任务为 recorded、样张为 accepted，再组装演示文稿。
11. 核验文件与交付路径，报告实际后端、页数及影响使用的限制，不将未完成内容称作成品。
12. 用户要求复用风格时，阅读[风格库](docs/style-library.md)，保存不含私人内容的视觉系统。

复杂任务保持简短进度更新，一个当前步骤，并用文件与状态证明完成；不是单靠聊天标记完成。

## 参考入口

- [可编辑重建与精编动画](docs/editable-refined-animation.md)：原生重建、校准、组件、节奏、放映与交付。
- [阶段与进度](docs/workflow-gates-and-progress.md)：确认节点与证据。
- [后端选择](docs/backend-selection.md)：内置能力和后备方案。
- [大纲、风格与样张](docs/outline-style-and-sample.md)：逐页内容、参考风格、样张。
- [用户素材](docs/user-supplied-assets.md)：图表、截图与标志保真。
- [生成与分工](docs/slide-generation-and-subagents.md)：任务、状态、分派与记录。
- [命令行后备方案](docs/cli-api-fallback.md)：命令、图片输入、透明背景。
- [模型配置](docs/image-model-configuration.md)：仅配置缺失、错误或用户要求时读取。
- [项目与组装](docs/project-assembly-and-reporting.md)：目录、讲稿与组装。
- [风格库](docs/style-library.md)：保存个人风格。
- [单页工作者模板](prompts/slide-worker.md)：图片任务交接。
- references/：随技能分发的风格。个人风格放在技能安装目录之外的共享风格目录，按风格库规则发现和优先使用。
