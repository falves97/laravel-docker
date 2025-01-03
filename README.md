# Laravel FrankenPHP Template

Este projeto é um template para projetos em Laravel, utilizando FrankenPHP para manter o PHP nas versões mais recentes
junto do Laravel. Para otimizar a performance, o template usa o Laravel Octane. O template conta com configurações para
desenvolvimento local, como XDebug, e para deploy em produção com otimização da imagem Docker usando camadas.

## Estrutura do Projeto

- **Laravel**: Framework PHP para desenvolvimento web.
- **FrankenPHP**: Mantém o PHP atualizado com as versões mais recentes.
- **Laravel Octane**: Otimiza a performance do Laravel.
- **Docker**: Configurações para desenvolvimento e produção.

## Configurações de Desenvolvimento

- **XDebug**: Ferramenta de depuração para PHP.
- **Node.js**: Inclui Node.js para gerenciamento de pacotes e build de frontend.

## Configurações de Produção

- **Otimização da Imagem Docker**: Uso de camadas para otimizar a imagem Docker.
- **Configurações de Performance**: Laravel Octane para melhorar a performance.

## Como Usar

### Desenvolvimento Local

1. Construa e inicie os containers Docker:
    ```sh
    docker compose build --no-cache
    docker compose up --pull always -d --wait
    ```

2. Acesse o ambiente de desenvolvimento e aceite o certificado SSL autoassinado:
    ```
    https://localhost
    ```

### Deploy em Produção

1. Inicie o container de produção:
    ```sh
    docker compose -f compose.yaml -f compose.prod.yaml up -d --wait
    ```
   
## Contribuição

Sinta-se à vontade para contribuir com este projeto. Faça um fork do repositório, crie uma branch para suas alterações e
envie um pull request.

## Licença

Este projeto está licenciado sob a [MIT License](LICENSE).