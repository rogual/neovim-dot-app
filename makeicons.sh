ICONSET=build/temp.iconset

mkdir -p $ICONSET

sips -z 16 16     $2 --out $ICONSET/icon_16x16.png
sips -z 32 32     $2 --out $ICONSET/icon_16x16@2x.png
sips -z 32 32     $2 --out $ICONSET/icon_32x32.png
sips -z 64 64     $2 --out $ICONSET/icon_32x32@2x.png
sips -z 128 128   $2 --out $ICONSET/icon_128x128.png
sips -z 256 256   $2 --out $ICONSET/icon_128x128@2x.png
sips -z 256 256   $2 --out $ICONSET/icon_256x256.png
sips -z 512 512   $2 --out $ICONSET/icon_256x256@2x.png
sips -z 512 512   $2 --out $ICONSET/icon_512x512.png
cp $2 $ICONSET/icon_512x512@2x.png
iconutil -c icns -o $1 $ICONSET
rm -R $ICONSET
