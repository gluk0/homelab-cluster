
    echo "  kubectl create namespace nightscout"
    echo "  kubectl create secret generic nightscout-config -n nightscout \\"
    echo "    --from-literal=mongodb-uri='mongodb://...' \\"
    echo "    --from-literal=api-secret='your-secret-min-12-chars'"
 