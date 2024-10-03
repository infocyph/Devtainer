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


### Recommended Max Upload Values Based on Use Cases:
| Use Case                        | Recommended `client_max_body_size` |
|----------------------------------|------------------------------------|
| Simple Websites (No uploads)     | 1 MB - 2 MB (default)              |
| Image Uploads / Small Files      | 5 MB - 10 MB                       |
| Document Management / CMS        | 10 MB - 50 MB                      |
| Video Uploads / Media Platforms  | 100 MB or more                     |
| API Payloads                     | 1 MB - 10 MB                       |
