"""Makes every platform's app icon from the chosen artwork, design/icon/source.jpg (2000 × 1116, the icon
tile in the middle on dark green), used as it is:
    python3 design/icon/install-icons.py
"""
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

here = os.path.dirname(os.path.abspath(__file__))
root = os.path.join(here, '..', '..')
source = Image.open(os.path.join(here, 'source.jpg')).convert('RGB')

# The tile's gold frame (outer edge) in the source, and the artwork inside the frame.
FRAME = (549, 100, 1452, 1017)
INSIDE = (580, 131, 1421, 986)
GREEN = (6, 40, 30)
# The artwork's colour along the inside of the frame, for the Android background layer.
EDGE = (10, 42, 34)


def crop(box, pad=0):
    l, t, r, b = box
    return source.crop((l - pad, t - pad, r + pad, b + pad))


def rounded_mask(size, radius):
    mask = Image.new('L', size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius=radius, fill=255)
    return mask


def save(image, size, *rel):
    path = os.path.join(root, *rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    image.resize(size, Image.LANCZOS).save(path, optimize=True)
    print('  ', os.path.join(*rel), size)


# Full-bleed square: the framed tile with a margin of the source's own green, so a platform's rounded
# corners (iOS, launchers) don't cut the frame.
square = crop(FRAME, pad=46).resize((1024, 1024), Image.LANCZOS)

# Rounded tile, transparent around it: the frame's own shape (macOS, Windows, the app's share card).
tile = crop(FRAME).resize((860, 860), Image.LANCZOS)
rounded = Image.new('RGBA', (1024, 1024), (0, 0, 0, 0))
shadow = Image.new('RGBA', (1024, 1024), (0, 0, 0, 0))
shadow.paste((0, 0, 0, 140), (82, 96, 942, 956), rounded_mask((860, 860), 110))
rounded.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(16)))
rounded.paste(tile, (82, 82), rounded_mask((860, 860), 110))

# Android adaptive icon (108 dp; launchers show the middle 72 dp, cut to a circle or rounded square): the
# artwork inside the frame at 64 dp, its edges faded into a blurred copy of it, so the calligraphy stays whole.
inside = crop(INSIDE)
art = inside.resize((640, 640), Image.LANCZOS).convert('RGBA')
fade = Image.new('L', (640, 640), 0)
ImageDraw.Draw(fade).rounded_rectangle((24, 24, 615, 615), radius=120, fill=255)
art.putalpha(fade.filter(ImageFilter.GaussianBlur(18)))
foreground = Image.new('RGBA', (1080, 1080), (0, 0, 0, 0))
foreground.paste(art, (220, 220), art)
background = Image.new('RGB', (1080, 1080), EDGE)


def circle(image):
    out = image.convert('RGBA')
    out.putalpha(rounded_mask(out.size, out.size[0] // 2))
    return out


res = ('flutter_app', 'android', 'app', 'src', 'main', 'res')
for density, scale in (('mdpi', 1), ('hdpi', 1.5), ('xhdpi', 2), ('xxhdpi', 3), ('xxxhdpi', 4)):
    legacy, layer = round(48 * scale), round(108 * scale)
    save(square, (legacy, legacy), *res, f'mipmap-{density}', 'ic_launcher.png')
    save(circle(inside), (legacy, legacy), *res, f'mipmap-{density}', 'ic_launcher_round.png')
    save(foreground, (layer, layer), *res, f'mipmap-{density}', 'ic_launcher_foreground.png')
    save(background, (layer, layer), *res, f'mipmap-{density}', 'ic_launcher_background.png')

save(square, (1024, 1024), 'flutter_app', 'ios', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset', 'icon-1024.png')
save(rounded, (1024, 1024), 'flutter_app', 'assets', 'AppIcon.png')
save(rounded, (1024, 1024), 'MushafMac', 'Assets', 'AppIcon.png')
ico = os.path.join(root, 'flutter_app', 'windows', 'runner', 'resources', 'app_icon.ico')
rounded.resize((256, 256), Image.LANCZOS).save(ico, sizes=[(s, s) for s in (16, 24, 32, 48, 64, 128, 256)])
print('   flutter_app/windows/runner/resources/app_icon.ico')
save(square, (512, 512), 'website', 'assets', 'icon.png')
save(square, (512, 512), 'play-assets', 'icon-512.png')

# The TV banner and Google Play's feature graphic: the tile with the app's name beside it.
fonts = os.path.join(root, 'flutter_app', 'assets', 'fonts')


def banner(w, h, tile_size, arabic, latin, line=None):
    # The source's dark green, a little lighter behind the tile.
    out = Image.new('RGB', (w, h), (3, 30, 24))
    light = Image.new('L', (w, h), 0)
    ImageDraw.Draw(light).ellipse((-w * 0.1, -h * 0.2, w * 0.6, h * 1.2), fill=90)
    out.paste((10, 58, 44), (0, 0), light.filter(ImageFilter.GaussianBlur(h // 4)))
    t = crop(FRAME).resize((tile_size, tile_size), Image.LANCZOS)
    x, y = round(h * 0.09), (h - tile_size) // 2
    out.paste(t, (x, y), rounded_mask((tile_size, tile_size), round(tile_size * 0.128)))
    d = ImageDraw.Draw(out)
    cx = (x + tile_size + w) // 2
    ar = ImageFont.truetype(os.path.join(fonts, 'Amiri-Bold.ttf'), arabic, layout_engine=ImageFont.Layout.RAQM)
    la = ImageFont.truetype(os.path.join(fonts, 'Amiri-Bold.ttf'), latin)
    d.text((cx, h * 0.47), 'مصحف', font=ar, fill=(232, 196, 112), anchor='ms', direction='rtl', language='ar')
    d.text((cx, h * 0.66), "Mus'haf", font=la, fill=(244, 236, 214), anchor='ms')
    if line:
        small = ImageFont.truetype(os.path.join(fonts, 'Amiri-Regular.ttf'), line, layout_engine=ImageFont.Layout.RAQM)
        d.text((cx, h * 0.79), 'The Madinah Mushaf · مصحف المدينة', font=small, fill=(220, 214, 196), anchor='ms')
    return out


save(banner(1280, 720, 560, 200, 84), (320, 180), *res, 'drawable-xhdpi', 'tv_banner.png')
save(banner(1280, 720, 560, 200, 84), (1280, 720), 'play-assets', 'tv', 'tv-banner-1280x720.png')
save(banner(1024, 500, 400, 150, 56, line=30), (1024, 500), 'play-assets', 'feature-graphic-1024x500.png')
