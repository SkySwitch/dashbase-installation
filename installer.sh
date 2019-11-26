#export DASHBASE_HOME=/dashbase

kubectl apply -f dashbase-admin/ns.yml

# TODO scope the RBAC, using the cluster-admin yet.
kubectl apply -f dashbase-admin/rbac.yml

kubectl apply -f dashbase-admin/deployment.yml

kubectl wait --for=condition=available deployment/dashbase-installer -n dashbase

PODNAME=$(kubectl get po -n dashbase -o=jsonpath='{.items[0].metadata.name}' -l app=dashbase,component=installer)

kubectl exec -it "${PODNAME}" -n dashbase -- helm --tiller-namespace dashbase init --service-account dashbase-admin --wait

kubectl exec -it "${PODNAME}" -n dashbase -- kubectl wait --for=condition=available deployment/tiller-deploy -n dashbase

kubectl exec -it "${PODNAME}" -n dashbase -- helm --tiller-namespace dashbase ls

kubectl exec -it "${PODNAME}" -n dashbase -- helm repo add dashbase https://charts.dashbase.io

#kubectl exec -it "${PODNAME}" -n dashbase -- curl https://raw.githubusercontent.com/dashbase/dashbase-installation/d5f450c12eb837538780142765a85848ce27635d/configs/dashcomm/values.yml > $DASHBASE_HOME/values.yml

# TODO fix the HTTPS certificates.

# TODO fix the persistence storage.
