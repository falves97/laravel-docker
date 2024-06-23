# Node container

## Chaves para SSH

Devido o FrankenPHP já gerar automaticamente um Certificado SSL para conexão por HTTPS, por padrão.
É necessário que o servido do vite também funcione com HTTPS, para evitar problemas de comunicação entre eles.

Para fazer isso, você pode gerar o seu próprio certifica autoassinado, para ambiente local. Com o comando.

``` shell
openssl req -newkey rsa:4096 \
            -x509 \
            -sha256 \
            -days 3650 \
            -nodes \
            -out localhost.crt \
            -keyout localhost.key \
            -subj "/C=BR/ST=Maranhão/L=São Luís/O=Company Name/OU=Unity Compane Name/CN=localhost"
```

Ao usar certificados não confiáveis, será necessário aceitar o aviso de certificado do servidor de desenvolvimento do Vite no navegador, 
seguindo o link “Local” no console ao executar o comando npm run dev.