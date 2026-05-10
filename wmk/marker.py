#!/usr/bin/python
# -*- coding: utf-8 -*-

import argparse
import os
import sys
import math
import textwrap

from PIL import Image, ImageFont, ImageDraw, ImageEnhance, ImageChops, ImageOps


def add_mark(imagePath, mark, args):
    """
    添加水印，然后保存图片
    :param imagePath:
    :param mark:
    :param args:
    :return:
    """
    im = Image.open(imagePath)
    im = ImageOps.exif_transpose(im)

    image = mark(im)
    name = os.path.basename(imagePath)
    if image:
        if not os.path.exists(args.out):
            os.mkdir(args.out)

        new_name = os.path.join(args.out, name)
        if os.path.splitext(new_name)[1] != '.png':
            image = image.convert('RGB')
        image.save(new_name, quality=args.quality)

        print(name + " Success.")
    else:
        print(name + " Failed.")


def set_opacity(im, opacity):
    """
    设置水印透明度
    :param im:
    :param opacity:
    :return:
    """
    assert opacity >= 0 and opacity <= 1

    alpha = im.split()[3]
    alpha = ImageEnhance.Brightness(alpha).enhance(opacity)
    im.putalpha(alpha)
    return im


def crop_image(im):
    """
    裁剪图片边缘空白
    :param im:
    :return:
    """
    bg = Image.new(mode='RGBA', size=im.size)
    diff = ImageChops.difference(im, bg)
    del bg
    bbox = diff.getbbox()
    if bbox:
        return im.crop(bbox)
    return im


def gen_mark(args):
    """
    生成mark图片，返回添加水印的函数
    :param args:
    :return:
    """
    # 字体宽度、高度
    is_height_crop_float = '.' in args.font_height_crop  # not good but work
    width = len(args.mark) * args.size
    if is_height_crop_float:
        height = round(args.size * float(args.font_height_crop))
    else:
        height = int(args.font_height_crop)

    # 创建水印图片(宽度、高度)
    mark = Image.new(mode='RGBA', size=(width, height))

    # 生成文字
    draw_table = ImageDraw.Draw(im=mark)
    draw_table.text(xy=(0, 0),
                    text=args.mark,
                    fill=args.color,
                    font=ImageFont.truetype(args.font_family,
                                            size=args.size))
    del draw_table

    # 裁剪空白
    mark = crop_image(mark)

    # 透明度
    set_opacity(mark, args.opacity)

    def mark_im(im):
        """
        在im图片上添加水印 im为打开的原图
        :param im:
        :return:
        """
        if getattr(args, 'position', None):
            # 只在原图上生成一个水印，支持旋转和位置关键字
            mark_img = mark.copy()
            if args.angle:
                mark_img = mark_img.rotate(args.angle, expand=True)
            pos = args.position.strip().lower()
            margin = 10  # 边距像素
            pos_map = {
                'left': lambda s, ms: margin,
                'center': lambda s, ms: (s - ms) // 2,
                'right': lambda s, ms: s - ms - margin,
                'top': lambda s, ms: margin,
                'bottom': lambda s, ms: s - ms - margin
            }
            x, y = 0, 0
            if ',' in pos:
                px, py = pos.split(',', 1)
                def parse_val(val, size, msize):
                    val = val.strip()
                    if val in pos_map:
                        v = pos_map[val]
                        v = v(size, msize) if callable(v) else v
                        if isinstance(v, (int, float, str)):
                            return int(v)
                        else:
                            return 0
                    try:
                        return int(val)
                    except Exception:
                        return 0
                x = parse_val(px, im.size[0], mark_img.size[0])
                y = parse_val(py, im.size[1], mark_img.size[1])
            # 边界修正，防止超出
            x = max(0, min(x, im.size[0] - mark_img.size[0]))
            y = max(0, min(y, im.size[1] - mark_img.size[1]))
            if im.mode != 'RGBA':
                im = im.convert('RGBA')
            im.paste(mark_img, (x, y), mask=mark_img.split()[3])
            del mark_img
            return im
        else:
            # 计算斜边长度
            c = int(math.sqrt(im.size[0] * im.size[0] + im.size[1] * im.size[1]))

            # 以斜边长度为宽高创建大图（旋转后大图才足以覆盖原图）
            mark2 = Image.new(mode='RGBA', size=(c, c))

            # 平铺逻辑
            c = int(math.sqrt(im.size[0] * im.size[0] + im.size[1] * im.size[1]))
            mark2 = Image.new(mode='RGBA', size=(c, c))
            y, idx = 0, 0
            while y < c:
                # 制造x坐标错位
                x = -int((mark.size[0] + args.space) * 0.5 * idx)
                idx = (idx + 1) % 2

                while x < c:
                    # 在该位置粘贴mark水印图片
                    mark2.paste(mark, (x, y))
                    x = x + mark.size[0] + args.space
                y = y + mark.size[1] + args.space

            # 将大图旋转一定角度
            mark2 = mark2.rotate(args.angle)

            # 在原图上添加大图水印
            if im.mode != 'RGBA':
                im = im.convert('RGBA')
            im.paste(mark2,  # 大图
                    (int((im.size[0] - c) / 2), int((im.size[1] - c) / 2)),  # 坐标
                    mask=mark2.split()[3])
            del mark2
            return im

    return mark_im


def main():
    if len(sys.argv) == 1:
        print("Please use -h to see usage.")
        sys.exit(1)

    parse = argparse.ArgumentParser(formatter_class=argparse.RawTextHelpFormatter)
    parse.add_argument("-f", "--file", type=str,
                       help="image file path or directory")
    parse.add_argument("-m", "--mark", type=str, help="watermark content")
    parse.add_argument("-o", "--out", default="./output",
                       help="image output directory, default is ./output")
    parse.add_argument("-c", "--color", default="#8B8B1B", type=str,
                       help="text color like '#000000', default is #8B8B1B")
    parse.add_argument("-s", "--space", default=75, type=int,
                       help="space between watermarks, default is 75")
    parse.add_argument("-a", "--angle", default=30, type=int,
                       help="rotate angle of watermarks, default is 30")
    parse.add_argument("--font-family", default="./font/庞门正道标题体免费版.ttf", type=str,
                       help=textwrap.dedent('''\
                       font family of text, default is './font/庞门正道标题体免费版.ttf'
                       using font in system just by font file name
                       for example 'PingFang.ttc', which is default installed on macOS
                       '''))
    parse.add_argument("--font-height-crop", default="1.2", type=str,
                       help=textwrap.dedent('''\
                       change watermark font height crop
                       float will be parsed to factor; int will be parsed to value
                       default is '1.2', meaning 1.2 times font size
                       this useful with CJK font, because line height may be higher than size
                       '''))
    parse.add_argument("--size", default=50, type=int,
                       help="font size of text, default is 50")
    parse.add_argument("--opacity", default=0.15, type=float,
                       help="opacity of watermarks, default is 0.15")
    parse.add_argument("--quality", default=80, type=int,
                       help="quality of output images, default is 80")
    # 新增 position 参数
    parse.add_argument("-p", "--position", type=str, default=None,
                       help=textwrap.dedent('''\
                       watermark position, format: 'x,y' (e.g. 100,200) or keywords like 'left,top', 'center,center', 'right,bottom'.
                       If set, only one watermark will be placed at the specified position.
                       '''))

    args = parse.parse_args()

    if isinstance(args.mark, str) and sys.version_info[0] < 3:
        args.mark = args.mark.decode("utf-8")

    mark = gen_mark(args)

    if os.path.isdir(args.file):
        names = os.listdir(args.file)
        for name in names:
            image_file = os.path.join(args.file, name)
            add_mark(image_file, mark, args)
    else:
        add_mark(args.file, mark, args)


if __name__ == '__main__':
    main()