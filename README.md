# GitHub Users

App iOS em SwiftUI para explorar usuários do GitHub e consultar seus perfis. A lista tem paginação, alternância entre grade e lista e busca entre os usuários já carregados.

Repositório: [swiftdecodificado/GitHubUsers](https://github.com/swiftdecodificado/GitHubUsers).

## Demonstração

> Espaço reservado para o GIF do app rodando no simulador.

<!--
Substitua o bloco acima pelo GIF quando estiver disponível:
![GitHub Users no simulador: lista, busca, perfil e avatar](URL_DO_GIF)
-->

## Funcionalidades

- Listagem paginada em grupos de 30 usuários, com grade adaptável à largura da tela.
- Busca local por login e nome, quando disponível, sem diferenciar maiúsculas ou acentos.
- Perfil com avatar, bio, contagens de repositórios, seguidores e seguindo, além das informações públicas disponíveis.
- Avatar em tela cheia, com fechamento por toque, gesto ou botão.
- Atualização ao puxar a lista e ao retornar do segundo plano. Se uma atualização falhar, o conteúdo já carregado permanece visível.
- Estados de carregamento, lista vazia e erro, com nova tentativa e espera quando o limite de requisições é atingido.
- Textos em português e inglês, rótulos de acessibilidade e ajustes para redução de movimento e transparência.

A busca filtra a lista em memória. Para incluir mais usuários nos resultados, limpe a busca e carregue novas páginas pela rolagem.

## Como o projeto está organizado

As Views apresentam os estados mantidos por `UsersListViewModel` e `UserDetailViewModel`. A navegação entre lista e perfil fica no `NavigationStack` de `AppRootView`.

Os ViewModels recebem um `GitHubClientProtocol`. Na execução normal, `GitHubClient` consulta a API com `URLSession` e `async/await`, valida as respostas HTTP e decodifica o JSON com `JSONDecoder` e modelos `Decodable`. Nos testes, essa dependência pode ser substituída para controlar respostas e falhas.

O pacote local `GitHubAPI` também reúne os modelos e os caches: usuários e perfis ficam em memória; os dados dos avatares são armazenados em memória e em disco. O app usa SwiftUI e Combine para apresentar as mudanças de estado.

```text
Config/                  Configurações de build e exemplo de assinatura
Sources/
  App/                   Entrada, dependências e navegação
  Features/
    UsersList/           Lista, busca, paginação e seus componentes
    UserDetail/          Perfil, avatar e seus componentes
  Components/            Componentes visuais compartilhados
  Support/               Formatação, localização e apresentação de erros
  Preview/               Dados e cliente simulado para Debug
  Resources/             Catálogo de traduções
Packages/GitHubAPI/       Cliente HTTP, modelos, caches e testes do pacote
Tests/                   Testes dos ViewModels, mocks e fixtures
UITests/                 Testes de interface com XCTest
Package.swift            Lógica de apresentação testável no macOS
project.yml              Definição do projeto para o XcodeGen
GitHubUsers.xcodeproj/    Projeto Xcode gerado
```

## Executar

É necessário um Mac com Xcode e toolchain Swift 6.3 ou superior. O app exige iOS 17 ou superior; os testes de pacote no macOS exigem macOS 14 ou superior.

```sh
git clone https://github.com/swiftdecodificado/GitHubUsers.git
cd GitHubUsers
open GitHubUsers.xcodeproj
```

No Xcode, selecione o scheme `GitHubUsers`, escolha um simulador e execute com **⌘R**. O app consulta a API sem token e precisa de internet para buscar dados novos.

Para executar em um iPhone, copie [Config/Signing.xcconfig.example](Config/Signing.xcconfig.example) para `Config/Signing.xcconfig` e preencha `DEVELOPMENT_TEAM` com o ID do seu Team. O arquivo local é ignorado pelo Git.

## Configuração do projeto

[project.yml](project.yml) define os targets, as dependências, o scheme e a versão mínima do iOS. [Config/Project.xcconfig](Config/Project.xcconfig) concentra as opções compartilhadas; [Config/App.xcconfig](Config/App.xcconfig) define a versão, o nome e as orientações do app.

O projeto usa o modo de linguagem Swift 6. Para alterar a estrutura e regenerar o `.xcodeproj`, edite `project.yml` e execute com o XcodeGen instalado:

```sh
xcodegen generate --spec project.yml
```

O scheme está configurado para executar sem LLDB. Para usar breakpoints, altere `run.debugEnabled` para `true` em `project.yml` e regenere o projeto.

## Testes

Os testes unitários usam Swift Testing e exercitam carregamento, paginação, busca, cancelamento, recuperação de erros, respostas HTTP e caches. Execute os dois comandos na raiz:

```sh
swift test
swift test --package-path Packages/GitHubAPI
```

O primeiro executa os testes dos ViewModels; o segundo executa os testes do pacote `GitHubAPI`.

Os testes de interface usam XCTest para exercitar navegação, busca, troca de layout, paginação, rotação, avatar e recuperação de falhas. No Xcode, use **⌘U** com o scheme `GitHubUsers`. Esses testes iniciam o app com dados simulados, sem depender da API; o cliente simulado e os argumentos de teste são compilados apenas em Debug.
