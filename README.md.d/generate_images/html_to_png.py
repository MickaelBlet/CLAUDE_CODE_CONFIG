#!/usr/bin/env python3
# -*- coding:utf-8 -*-

import os
from html2image import Html2Image

folder_path = os.path.dirname(os.path.realpath(__file__))

for filename in os.listdir(folder_path):
    if filename.endswith('.html'):
        filepath = os.path.join(folder_path, filename)
        hti = Html2Image(output_path=folder_path + "/../images/", size=(830, 10000))
        # screenshot an HTML file
        hti.screenshot(
            url="file://" + filepath, save_as=os.path.splitext(os.path.basename(filepath))[0] + ".png"
        )

        from PIL import Image
        img = Image.open(folder_path + "/../images/" + os.path.splitext(os.path.basename(filepath))[0] + ".png")

        # Get the content bounds.
        content = img.getbbox()

        # Crop the image.
        img = img.crop(content)

        # Save the image.
        img.save(folder_path + "/../images/" + os.path.splitext(os.path.basename(filepath))[0] + ".png")