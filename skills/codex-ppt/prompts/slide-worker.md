# 单页图片工作者交接模板

用于图片样张认可且已授权全篇生成后。主代理补齐下列实际值，不省略图片上下文。

    请完成第 N 页。
    项目目录：实际绝对路径
    任务文件：prompts/slide_NN.json 的实际绝对路径
    父代理管理的最终路径：origin_image/slide_NN.png
    已选择后端：精确后端标签
    样张生成方法：backend_used、tool_name、mode、模型与参数（若暴露）、
                  prompt_source、input_context_preparation、approved_sample_path、handoff_rule
    已提供图片：逐项列出实际路径及严格素材/仅风格参考的角色。

读取任务并执行 prompt，使用记录的同一后端、工具与方式。内置模式实际调用内置生图或编辑；后备模式调用 image_gen.py 并传入全部必需图片。

不能用本地绘图、网页/原生排版截图、手工叠字或近似重画证据替代最终生图。无法使用所选路径或样张方法时返回 blocker=具体原因，不自行换方法。

不编辑任务、最终目录、讲稿，不组装整套PPT。回报前检查中文、素材保真、风格、截断与遮挡。

返回字段属于状态接口，字段名保留原样，说明使用中文：

    backend_used=实际后端标签
    selected_source=实际候选图片绝对路径
    qa_note=一句话检查结论

发生阻塞时返回 blocker=原因。
