FROM python:3.6-alpine

# Note: Latest version of kubectl may be found at:
# https://github.com/kubernetes/kubernetes/releases
ENV KUBE_LATEST_VERSION="v1.16.3"

# Note: Latest version of helm may be found at:
# https://github.com/kubernetes/helm/releases
#ENV HELM_VERSION="v3.0.0"
ENV HELM_VERSION="v3.1.1"

# Default timezone: UTC
ENV TZ=UTC

RUN apk update && apk upgrade

RUN apk add --no-cache ca-certificates bash git openssh curl \
    && wget -q https://storage.googleapis.com/kubernetes-release/release/${KUBE_LATEST_VERSION}/bin/linux/amd64/kubectl -O /usr/local/bin/kubectl \
    && chmod +x /usr/local/bin/kubectl \
    && wget -q https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz -O - | tar -xzO linux-amd64/helm > /usr/local/bin/helm \
    && chmod +x /usr/local/bin/helm

RUN pip install --upgrade pip

# RUN pip install awscli --upgrade

# RUN curl --silent --location "https://github.com/weaveworks/eksctl/releases/download/latest_release/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /usr/local/bin
# RUN curl -sSL https://sdk.cloud.google.com | bash

# ENV PATH $PATH:/root/google-cloud-sdk/bin

RUN mkdir -p /dashbase
RUN mkdir -p /usr/local/lib/dashbase

ADD .bash_profile /dashbase
ADD docker-entrypoint.sh /dashbase
RUN chmod +x /dashbase/docker-entrypoint.sh
RUN apk add --no-cache su-exec
RUN apk add --update util-linux
RUN apk add --update openssh && rm -rf /tmp/* /var/cache/apk/*
RUN apk add --update openjdk8-jre
RUN apk add --update openssl
RUN apk add --update coreutils

ADD validate-license.py /dashbase
RUN chmod +x /dashbase/validate-license.py

COPY requirements.txt /dashbase
COPY dashbase-values.yaml /dashbase

RUN pip install -r /dashbase/requirements.txt

WORKDIR /dashbase
ENTRYPOINT ["/dashbase/docker-entrypoint.sh"]
EXPOSE 22
CMD ["/usr/sbin/sshd","-D"]
