FROM registry.access.redhat.com/ubi8:latest 
COPY checklink.sh /sbin
RUN curl -kL -o /bin/jq "https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64" && chmod +x /bin/jq
ENTRYPOINT ["/sbin/checklink.sh"] 
