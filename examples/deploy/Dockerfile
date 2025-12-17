FROM nginx:1.27-alpine

COPY dist/ /usr/share/nginx/html/
COPY default.conf /etc/nginx/conf.d/default.conf
COPY enterpoint.sh /usr/share/nginx/html/enterpoint.sh

RUN chmod +x /usr/share/nginx/html/enterpoint.sh

ENTRYPOINT ["/usr/share/nginx/html/enterpoint.sh"]
CMD ["nginx", "-g", "daemon off;"]

