import array
import fcntl
import subprocess
import termios

from PIL import Image
from ranger.ext.img_display import ImageDisplayer, register_image_displayer


def get_term_pixels_per_char():
    buf = array.array("H", [0, 0, 0, 0])
    fcntl.ioctl(1, termios.TIOCGWINSZ, buf)
    height = buf[3] / buf[0]
    width = buf[2] / buf[1]
    return width, height


@register_image_displayer("viu")
class ViuImageDisplayer(ImageDisplayer):
    def draw(self, path, start_x, start_y, width, height):
        # print("\033[%d;%dH" % (start_y, start_x + 1))

        char_w, char_h = get_term_pixels_per_char()

        width_px = width * char_w
        height_px = height * char_h

        img_width, img_height = Image.open(path).size

        aspect_ratio_img = img_width / img_height
        aspect_ratio_screen = width_px / height_px

        if aspect_ratio_img > aspect_ratio_screen:
            draw_cmd = [
                "viu",
                path,
                "--absolute-offset",
                "-x",
                str(start_x),
                "-y",
                str(start_y),
                "--width",
                str(width),
            ]
        else:
            draw_cmd = [
                "viu",
                path,
                "--absolute-offset",
                "-x",
                str(start_x),
                "-y",
                str(start_y),
                "--height",
                str(height),
            ]
        subprocess.run(draw_cmd)

    def clear(self, start_x, start_y, width, height):
        cleaner = " " * width
        for i in range(height):
            print("\033[%d;%dH" % (start_y + i, start_x + 1))
            print(cleaner)
