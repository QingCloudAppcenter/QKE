KS_CONSOLE_URL=$(/opt/kubernetes/script/get-ks-console-url.sh)

echo { \
    \"labels\": [ \"KubeSphere Console URL\"], \
    \"data\":\
    [\
        [\"${KS_CONSOLE_URL}\"]\
    ]\
}