# v 0.3.0
FROM alpine:3.15.4

RUN apk update && apk add --no-cache --update --verbose logrotate grep bash && \
    rm -rf /var/cache/apk/* /tmp/* /sbin/halt /sbin/poweroff /sbin/reboot

COPY curlbeat.conf /etc/logrotate.d/curlbeat.conf
RUN chmod 644 /etc/logrotate.d/curlbeat.conf && cp /etc/periodic/daily/logrotate /etc/periodic/hourly/logrotate
