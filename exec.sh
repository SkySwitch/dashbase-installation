PODNAME=$(kubectl get po -n dashbase -o=jsonpath='{.items[0].metadata.name}' -l app=dashbase,component=installer)

kubectl exec -it "${PODNAME}" -n dashbase /bin/bash