FROM httpd:alpine
COPY ./pub/ /usr/local/apache2/htdocs/
