# Devtainer
Docker based local development environment for PHP based projects

docker-compose run certbot certonly --webroot --webroot-path=/var/www/certbot -d example.com -d www.example.com


docker exec -it certbot certbot certonly --webroot \
--webroot-path=/var/www/certbot \
--email your-email@example.com \
--agree-tos \
--no-eff-email \
-d example.com \
-d www.example.com

docker exec -it certbot certbot renew --deploy-hook "docker exec -it nginx nginx -s reload"
docker exec -it certbot certbot renew --deploy-hook "docker exec -it apache apachectl graceful"


