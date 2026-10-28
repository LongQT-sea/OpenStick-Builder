# extract Qualcomm firmware (com verificação de integridade)
BOOTLOADER_URL="https://releases.linaro.org/96boards/dragonboard410c/linaro/rescue/21.12/dragonboard-410c-bootloader-emmc-linux-176.zip"

echo "Baixando bootloader de: ${BOOTLOADER_URL}"
curl -fL --retry 3 --retry-delay 5 -o "${TMPDIR}/db410c-bootloader.zip" "${BOOTLOADER_URL}"

# Verificar que o download é realmente um ZIP (não uma página HTML de erro)
if ! file "${TMPDIR}/db410c-bootloader.zip" | grep -qi "zip archive"; then
    echo "ERRO: o download não é um ZIP válido."
    echo "Primeiros bytes do arquivo recebido:"
    head -c 200 "${TMPDIR}/db410c-bootloader.zip"
    echo
    exit 1
fi

echo "ZIP válido, extraindo bootloaders..."
unzip -o -j -d files/ "${TMPDIR}/db410c-bootloader.zip" \
    "dragonboard-410c-bootloader-emmc-linux-176/rpm.mbn" \
    "dragonboard-410c-bootloader-emmc-linux-176/sbl1.mbn" \
    "dragonboard-410c-bootloader-emmc-linux-176/tz.mbn"
}

trap 'cleanup $?' EXIT
