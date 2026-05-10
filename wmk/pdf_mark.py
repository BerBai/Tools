"""

[WaterMarker: A small tool for adding watermarks to pdf]

Copyright (C) 2024 Ber <bai5775@outlook.com>

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public
License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied
warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
You should have received a copy of the GNU General Public License along with this program; if not, write to the Free
Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.

"""

import os
import argparse
from PyPDF2 import PdfReader, PdfWriter
from reportlab.lib.units import cm
from reportlab.pdfgen import canvas
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfbase import pdfmetrics
import re
import pdfplumber
import fitz
import json

import notionnext

pdfmetrics.registerFont(TTFont('庞门正道标题体免费版', './font/庞门正道标题体免费版.ttf'))  # 注册字体

last_width = 0
last_height = 0


def deleteContent(pdf_path, output_path, del_text, modify=False):
    '''
    清除非必要信息
    :param pdf_path: 文件路径
    :param output_path: 保存路径
    :param del_text: 删除内容
    :param modify: 是否修改，修改内容
    :return:
    '''
    pdf_document = fitz.open(pdf_path)

    for page in pdf_document:
        page.clean_contents()
        content = page.get_text('json')  # json格式
        info = json.loads(content)
        try:
            for block in info['blocks']:
                for line in block['lines']:
                    for span in line['spans']:
                        text = span.get('text', '')
                        # 精准删除
                        if text == del_text:
                            key = span
                            if modify == False:
                                # 删除
                                page.add_redact_annot(key['bbox'])
                                page.apply_redactions()
                            else:
                                # 修改
                                page.add_redact_annot(key['bbox'], modify, fontname='china-s', fontsize=key['size'])
                                page.apply_redactions()
        except KeyError:
            print("-----error", KeyError)
            continue

    pdf_document.save(output_path)
    pdf_document.close()


def fileinfo(pdfpath):
    """
    文件信息
    :param pdfpath: 源文件
    :return:
    """
    with open(pdfpath, 'rb') as f:
        pdf = PdfReader(f)
        infomation = pdf.metadata
        number_of_pages = len(pdf.pages)

        txt = f'''{pdfpath} information:
        Author : {infomation.author},
        Creator : {infomation.creator},
        Producer : {infomation.producer},
        Subject : {infomation.subject},
        Title : {infomation.title},
        Number of pages : {number_of_pages}
        '''
        print(txt)


def title_page(pdf_file_in, pdf_file_out, area):
    with fitz.open(pdf_file_in) as pdf_fp:
        # print(pdf_fp[1])
        # field = pdf_fp[0].load_widget(724)
        # print(field)
        # pdf_fp[0].delete_widget()
        # pdf_fp[0].add_rect_annot(rect1)
        titlepage = pdf_fp[0]
        # titlepage.draw_rect((10, 10, 700, 400), color=(1, 1, 1), fill=(1, 1, 1), width=0)
        pagesize = titlepage.mediabox
        print(pagesize.width, pagesize.height)

        ff = titlepage.insert_font(fontname="庞门正道标题体免费版", fontfile=r"./font/庞门正道标题体免费版.ttf",
                                   fontbuffer=None,
                                   set_simple=False)  # 定义黑体
        titlepage.insert_text((pagesize.width / 2 - 100, 230), "E大微博", fontname="庞门正道标题体免费版", fontsize=60,
                              color=(0, 0, 0, 1), fill=None, render_mode=0,
                              border_width=1, rotate=0, morph=None, overlay=True)
        titlepage.insert_text((pagesize.width / 2 - 190, 330), "2024年03月合集", fontname="庞门正道标题体免费版",
                              fontsize=50, color=(0, 0, 0, 1),
                              fill=None, render_mode=0,
                              border_width=1, rotate=0, morph=None, overlay=True)
        # titlepage.insert_font(rect, "E⼤微博")
        pdf_fp.save(pdf_file_out)


def create_watermark(content, width, height, args):
    """
    创建水印页
    :param content: 水印内容
    :param width: 页面宽度
    :param height: 页面高度
    :param args: 配置参数，字体，水印参数等
    :return:
    """
    # 默认大小为21cm*29.7cm(A4)
    file_name = "mark.pdf"
    # 比例，用于自适应 pdf 页面大小
    width = float(width) * 0.0352
    height = float(height) * 0.0352
    ratio_w = width / 21
    ratio_h = height / 29.7
    c = canvas.Canvas(file_name, pagesize=(width * cm, height * cm))

    # 设置页眉页脚字体，默认采用 庞门正道标题体免费版.ttf 字体
    c.setFont(args.font, 10)
    c.setFillColor("#808080", 1)
    text_width = c.stringWidth("垃圾堆里捡宝藏", args.font, 10 * (ratio_w + ratio_h) / 2)
    c.drawString(0.9 * cm, (height - 1.5) * cm, "https://etf.125520.xyz")
    c.drawString((width - 0.9 - text_width * 0.0352) * cm, (height - 1.5) * cm, "垃圾堆里捡宝藏")

    c.setFont(args.font, 16)
    etftext_width = c.stringWidth("ETF拯救世界", args.font, 16 * (ratio_w + ratio_h) / 2)
    c.drawString((width - etftext_width * 0.0352) / 2 * cm, (height - 1.5) * cm, "ETF拯救世界")
    c.drawString((width - etftext_width * 0.0352) / 2 * cm, 1 * cm, "ETF拯救世界")
    # 获取文本的宽度

    # 移动坐标原点(坐标系左下为(0,0))
    c.translate(10 * cm * ratio_w, 5 * cm * ratio_h)

    # 设置字体，默认采用 庞门正道标题体免费版.ttf 字体
    c.setFont(args.font, args.size * (ratio_w + ratio_h) / 2)
    # 指定描边的颜色
    c.setStrokeColorRGB(0, 1, 0)
    # 默认旋转30度,坐标系被旋转
    c.rotate(args.angle)
    # 指定填充颜色，不透明度
    c.setFillColor(args.color, args.opacity)
    c.setAuthor(content)

    for i in range(5):
        for j in range(10):
            # 使用 比例 自适应水印文字位置
            a = 10 * (i - 1) * ratio_w
            b = 5 * (j - 2) * ratio_h
            c.drawString(a * cm, b * cm, content)
    # 关闭并保存pdf文件
    c.save()
    return file_name


def add_watermark(pdf_file_in, pdf_file_out, args):
    """
    增加水印
    :param pdf_file_in: pdf源文件
    :param pdf_file_out: pdf输出文件
    :param args: 配置参数
    :return:
    """
    global last_height, last_width
    pdf_watermark = []

    # 添加目录
    pdf_file_in, cata_list = add_bookmark(pdf_file_in, r'\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}')
    # print(pdf_file_in, cata_list)

    pdf_output = PdfWriter()
    input_stream = open(pdf_file_in, 'rb')
    pdf_input = PdfReader(input_stream, strict=False)

    # 获取PDF文件的页数
    pageNum = len(pdf_input.pages)

    # 给每一页打水印
    for i in range(pageNum):
        page = pdf_input.pages[i]
        # 获取当前页面实际宽高
        width = pdf_input.pages[i].mediabox.width
        height = pdf_input.pages[i].mediabox.height
        if width != last_width or height != last_height:
            pdf_file_mark = create_watermark(watermark_text, width, height, args)  # 生成水印文件
            pdf_watermark = PdfReader(open(pdf_file_mark, 'rb'), strict=False)  # 读入水印pdf文件
            last_width = width
            last_height = height
        page.merge_page(pdf_watermark.pages[0])
        page.compress_content_streams()  # 压缩内容
        pdf_output.add_page(page)

    # 添加书签目录
    for elem in range(len(cata_list)):
        page_name = cata_list[elem][0][:-1]  # 目录信息
        page_num = int(cata_list[elem][1])  # 页码信息
        pdf_output.add_outline_item(page_name, page_num - 1, None)
    # 设置权限
    pdf_output.encrypt(owner_password=args.password, user_password='', permissions_flag=args.permissions)
    # 修改文件信息
    pdf_output.add_metadata({'/Author': 'etf.125520.xyz', '/Title': 'etf.125520.xyz', '/Creator': 'etf.125520.xyz',
                             '/Producer': 'Skia/PDF m119'})
    pdf_output.write(open(pdf_file_out, 'wb'))


def add_bookmark(pdfpath, pattern_key):
    """
    增加书签目录
    :param pdfpath: 文件路径
    :param pattern_key: 书签正则
    :return: 保存文件路径 书签列表
    """
    with pdfplumber.open(pdfpath) as pdf:
        cata_list = []
        for page in pdf.pages:
            text = page.extract_text()  # 提取文本
            # print(text)
            pattern = re.compile(pattern_key)
            matches = pattern.findall(text)
            for title in matches:
                page_num = re.sub("\D", "", str(page))
                cata_list.append((title, page_num))

    pdf_output = PdfWriter()
    pdf_input = PdfReader(pdfpath)

    pageCount = len(pdf_input.pages)
    for i in range(pageCount):
        pdf_output.add_page(pdf_input.pages[i])

    for elem in range(len(cata_list)):
        page_name = cata_list[elem][0][:-1]  # 目录信息
        page_num = int(cata_list[elem][1])  # 页码信息
        pdf_output.add_outline_item(page_name, page_num - 1, None)

    pdf_file_out = pdf_file_in.replace('.pdf', '') + '（带目录）.pdf'
    with open(pdf_file_out, 'wb') as fout:
        pdf_output.write(fout)
    return pdf_file_out, cata_list


if __name__ == '__main__':
    # 定义命令行解析器对象
    parser = argparse.ArgumentParser(description='WaterMarker of argparse')

    # 添加命令行参数
    parser.add_argument('-m', '--mark', default='watermark', help="Text to add watermark")
    parser.add_argument("-c", "--color", default="#8B8B1B", type=str,
                        help="text color like '#000000', default is #8B8B1B")
    parser.add_argument('-f', '--file', default='', help="The path to the file to add the watermark to")
    parser.add_argument('-s', '--size', type=int, default=30, help="Font size used for watermark text, defaults to 30, "
                                                                   "the size will adjust itself as the page changes")
    parser.add_argument('-o', '--output', default='', help="File output path after adding watermark (including the "
                                                           "file name), the default is the original file directory")
    parser.add_argument('-p', '--password', default='', type=str,
                        help="File encryption, can be used with the permissions parameter.")
    parser.add_argument('--permissions', default='', type=int,
                        help="Encrypted permissions, to be used in conjunction with the password parameter. For example, 4(=0b0100): read and print only.")
    parser.add_argument('--font', default='庞门正道标题体免费版', help="Font used for watermark text")
    parser.add_argument('--opacity', type=float, default=0.1,
                        help="Transparency of watermark text, between 0.0 and 1.0")
    parser.add_argument('--angle', type=int, default=30, help="Rotate the canvas by the angle theta (in degrees)")
    parser.add_argument('--info', default=False, help="View file information")
    parser.add_argument('--delete', default='', help="Content to be deleted")
    parser.add_argument('--modify', default=False, help="To replace the deleted content, the --del parameter is required.")
    parser.add_argument('--notionnext', default=False, help="notionnext customized content, do not use it at will")

    # 从命令行中结构化解析参数
    args = parser.parse_args()

    mark = ''
    if args.mark == 'watermark':
        mark = input("请输入水印文字：")
    watermark_text = args.mark if mark == '' else mark

    pdf_file_in = ''
    pdf_file_out = ''
    if args.file == '':
        pdf_file_in = input("请输入文件路径：").strip('"').strip(' ')
    else:
        pdf_file_in = args.file

    if args.info:
        fileinfo(args.file)

    if os.path.splitext(pdf_file_in)[-1] == ".pdf":
        pdf_file_in = pdf_file_in.replace('\\', '/')
        # 文件输出路径
        if args.output == '':
            pdf_file_out = pdf_file_in.replace('.pdf', '') + '（阿北）.pdf'
        else:
            pdf_file_out = args.output.replace('\\', '/')

        if args.delete != '':
            deleteContent(pdf_file_in, pdf_file_in, args.delete, args.modify)

        if args.notionnext:
            notionnext.etf_titlepage(pdf_file_in, pdf_file_in)
        add_watermark(pdf_file_in, pdf_file_out, args)
        print("添加水印成功")
        print("文件路径为: {}".format(pdf_file_out.replace('/', '\\')))
    else:
        print("输入文件不为pdf格式!!!")

# python pdf_mark.py -m 垃圾堆里捡宝藏 -f /Users/ber/Downloads/E大微博-2024年02月合集.pdf -p HRworker88 --permissions 4 --notionnext
