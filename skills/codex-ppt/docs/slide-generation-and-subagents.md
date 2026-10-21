# 图片页生成与分工

在全篇图片生产、准备任务、分派、记录结果或阻塞前阅读。原生可编辑与动画分支不受整页图片生成方式限制。

## 准备自包含任务

最终 slide_XX.png 必须由所选生图后端生成，不用本地绘图或叠字替代。大纲、风格、后端和样张认可后，建立 deck_spec.json、任务和讲稿；需提前规划时使用草稿名称。

deck_spec.json 包含样张的 sample_generation_method，随后准备任务：

    python {skill_root}/scripts/run_skill.py prepare --spec {base_dir}/{deck_name}/deck_spec.json --out-dir {base_dir}/{deck_name} --selected-backend "已确定的后端标签" --force

生成 prompts/slide_XX.json、slide_jobs.json、slide_run_state.json。保留现有格式，不创建多份互相冲突的状态源。

每个任务必须自包含。主代理把跨页核心概念、术语、定义和背景写入 deck_context，页内特定事实写入 local_context；“上面的观点”“六个特点”等引用须展开。工作者不能依靠未传入的主对话理解材料。

源图可写结构化 required_images，或带图片引用的说明；明确路径、角色、是否严格输入。非样张任务附认可样张作为风格参考。内置模式先查看源图，再按任务交接记录确保工作者有实际图片上下文。

## 提示结构

分开记录画幅、风格、布局角色与意图、具体文字、视觉元素、严格素材和约束。说明同一风格如何按页面语义改变构图，不每页都用三张卡片。

手写任务也必须包含 prompt、out、input_images，完整保存在 prompts/slide_XX.json。最终图中包含准确标题和要点；不生成无关水印、标志或多余页码。语言为中文时明确要求清晰准确。

## 分派与状态

主代理负责大纲、规格、任务、最终目录、质检、讲稿和组装。工作者仅负责指定页，不修改共享文件。

样张认可并获全篇授权后，运行环境支持子代理时按上游流程一页一个任务。并发不足分批执行；必需分工能力不可用时说明阻塞，不悄悄换本地低质量制作方式。当前用户指令与环境授权优先于默认分工安排。

认可样张在规格中标记 sample_approved 或 approved_sample，最终图已存在时工具记录 accepted。

    python {skill_root}/scripts/run_skill.py status {base_dir}/{deck_name}
    python {skill_root}/scripts/run_skill.py record-dispatch {base_dir}/{deck_name} --slide slide_02 --agent-id "实际代理编号" --agent-nickname "代理名称" --prompt-file prompts/slide_02.json

交接使用[工作者模板](../prompts/slide-worker.md)，传完整任务、已准备图片和样张生成方法。

## 结果与阻塞

    python {skill_root}/scripts/run_skill.py record-result {base_dir}/{deck_name} --slide slide_02 --agent-id "实际代理编号" --backend-used "built-in image tool" --selected-source "/实际生成图片路径.png" --qa-note "文字清楚，风格与样张一致"

后端标签必须与已选标签和样张记录一致，不能为了通过校验伪报来源。结果脚本将选择的图片复制到最终目录并记录。

    python {skill_root}/scripts/run_skill.py record-blocker {base_dir}/{deck_name} --slide slide_02 --agent-id "实际代理编号" --reason "所选生图后端在工作者环境不可用"

不能只聊天说“已完成”而不登记结果。后备调用按[命令行说明](cli-api-fallback.md)传全部必需图像，不能只提取文字提示忽略素材。

## 命名与收尾

origin_image/ 中仅保留 slide_01.png、slide_02.png 等两位补零最终页图。认可样张保留正确页码复用；草稿、变体、参考图放其他目录。

组装前核对无缺页、无多余最终图、全部非样张状态为 recorded、样张为 accepted。实际检查文字、源图、遮挡与风格后才交付。
