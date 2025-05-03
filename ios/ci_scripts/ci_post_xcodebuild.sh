#!/bin/sh

# İmzalama işlemini yapmak için komutların çalıştırılması

APP_PATH="${CI_PRODUCT_PATH}/${CI_PRODUCT_NAME}.app"
FRAMEWORKS_PATH="${APP_PATH}/Frameworks"
ENTITLEMENTS_PATH="${CI_WORKSPACE}/ios/Runner/Runner.entitlements"

echo "Frameworks dosya yolunu kontrol ediyorum: ${FRAMEWORKS_PATH}"
ls -la "${FRAMEWORKS_PATH}"

# Tüm framework'leri yeniden imzalama
echo "Flutter framework'lerini yeniden imzalıyorum..."
for FRAMEWORK in "${FRAMEWORKS_PATH}"/*
do
    echo "İmzalanıyor: ${FRAMEWORK}"
    /usr/bin/codesign --force --deep --sign "${CERTIFICATE_NAME}" --entitlements "${ENTITLEMENTS_PATH}" "${FRAMEWORK}"
done

# Ana uygulamayı yeniden imzalama
echo "Ana uygulamayı yeniden imzalıyorum..."
/usr/bin/codesign --force --deep --sign "${CERTIFICATE_NAME}" --entitlements "${ENTITLEMENTS_PATH}" "${APP_PATH}"

# İmzaların doğrulanması
echo "İmzaların doğrulanması:"
codesign -dv --verbose=4 "${APP_PATH}"

echo "Done re-signing app" 