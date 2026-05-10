

# https://blog.csdn.net/qq_52529296/article/details/132285020
import json
import os
import re

import fitz


def etf_titlepage(pdf_path, output_path, modify = False, modifytitle = False):
    '''
    清除扉页非必要信息，定制ETF
    :param pdf_path: 文件路径
    :param output_path: 保存路径
    :return:
    '''
    pdf_document = fitz.open(pdf_path)

    for page in pdf_document:
        page.clean_contents()
        content = page.get_text('json')  # json格式
        info = json.loads(content)
        i = 0
        stop_flag = False
        pattern = "^@\d{4}/\d{2}/\d{2}"
        stop_pattern = "^\d{4}-\d{2}-\d{2}"
        try:
            for block in info['blocks']:
                for line in block['lines']:
                    for span in line['spans']:
                        text = span.get('text', '')
                        # print(text, i)
                        i += 1
                        # 匹配并清除扉页时间，占位有点多，在页尾显示
                        match = re.search(pattern, text)
                        if match:
                            key = span
                            page.add_redact_annot(key['bbox'])
                            page.apply_redactions()

                        # 匹配结束标志
                        match = re.search(stop_pattern, text)
                        if match:
                            stop_flag = True
                            print("停止")

                        # 保留页眉
                        if stop_flag or i <= 7:
                            continue

                        # 无差别删除
                        print("删除\n")
                        key = span
                        page.add_redact_annot(key['bbox'])
                        page.apply_redactions()

        except KeyError:
            print("-----error", KeyError)

        # 结束扉页
        break

    # 遮蔽层
    titlepage = pdf_document[0]
    titlepage.draw_rect((10, 10, 700, 400), color=(1, 1, 1), fill=(1, 1, 1), width=0)

    # 生成标题
    pagesize = titlepage.mediabox
    if modifytitle == False:
        filename = os.path.basename(pdf_path).split('.')[0]
        title = filename.split('-')[0]
        subtitle = filename.split('-')[1]
    else:
        title = modifytitle.split('-')[0]
        subtitle = modifytitle.split('-')[1]

    ff = titlepage.insert_font(fontname="庞门正道标题体免费版", fontfile=r"./font/庞门正道标题体免费版.ttf",
                               fontbuffer=None,
                               set_simple=False)  # 定义黑体
    titlepage.insert_text((pagesize.width / 2 - 100, 230), title, fontname="庞门正道标题体免费版", fontsize=60,
                          color=(0, 0, 0, 1), fill=None, render_mode=0,
                          border_width=1, rotate=0, morph=None, overlay=True)
    titlepage.insert_text((pagesize.width / 2 - 190, 330), subtitle, fontname="庞门正道标题体免费版",
                          fontsize=50, color=(0, 0, 0, 1),
                          fill=None, render_mode=0,
                          border_width=1, rotate=0, morph=None, overlay=True)
    incremental = 1 if output_path == pdf_path else 0
    # encryption = 1 if output_path == pdf_path else 0
    pdf_document.save(output_path, incremental=incremental, encryption=0)
    pdf_document.close()
