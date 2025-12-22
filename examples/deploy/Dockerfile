FROM 2c9ttmy29gq3er.xuanyuan.run/nginx:1.29.3-alpine

RUN echo "Asia/shanghai" > /etc/timezone

ADD out /usr/share/nginx/html

COPY default.conf /etc/nginx/conf.d

# 解决容器启动环境变量替换问题
COPY enterpoint.sh /entrypoint.sh
RUN chmod 755 /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

CMD ["nginx", "-g", "daemon off;"]

EXPOSE 80
