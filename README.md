# 🛹 My Lessons – Gestão Inteligente de Escolas

🔧 **Requisitos de Software**  
- Docker ≥ 20.10  
- Docker Compose ≥ 2.0  
- Git  

⚡ Esta é a **versão de desenvolvimento** do projeto **My Lessons**.  
O repositório contém o código atualizado para demonstração e evolução da aplicação.  
O backend encontra-se **hospedado** em [https://mylessons.pt](https://mylessons.pt), pelo que **não é necessário executar o servidor localmente**.  

---

## 🏗️ Visão Geral do Projeto

O **My Lessons** é uma aplicação digital criada para apoiar a gestão administrativa e operacional de escolas desportivas, escolas de música e centros de explicações.

**Funcionalidades principais**:
- Gestão de Aulas Privadas e em Grupo  
- Gestão de Pagamentos e Modalidades de Pagamento  
- Acompanhamento de Progresso dos Alunos  
- Comunicação e Notificações In-App  

---

## 🌐 Acesso Online

- **Backend Web**:  
  [https://mylessons.pt](https://mylessons.pt)  
  **Credenciais de Teste**:  
  - Username: `admin`  
  - Password: `password`

- **Aplicação iOS via TestFlight**:  
  [Aceder ao TestFlight](https://testflight.apple.com/join/NUZAbPqm)

---

## 🔄 Clonar o Projeto

```bash
git clone https://github.com/DEISI-ULHT-TFC-2024-25/TFC-DEISI-AlunoG2122-My-Lessons-Gestao-Inteligente-de-Escolas.git
cd TFC-DEISI-AlunoG2122-My-Lessons-Gestao-Inteligente-de-Escolas
```

---

## 🐳 Ambiente com Docker

### 1. Construir Imagens e Instalar Dependências

```bash
# (Re)cria as imagens de backend, frontend e base de dados
docker-compose build

# Se alterares Dockerfile ou dependências, força rebuild:
docker-compose up --build -d
```

### 2. Executar Todos os Serviços

```bash
# Arranca todos os containers em background
docker-compose up -d
```

### 3. Ver Logs

```bash
docker-compose logs -f
```

---

## 🛠️ Operações Comuns

### Migrações e Super-utilizador

```bash
# Aplica migrações
docker-compose exec backend python manage.py migrate

# Cria um super-utilizador
docker-compose exec backend python manage.py createsuperuser
```

_As credenciais de teste continuam sendo `admin` / `password`, a não ser que seja criado outro usuário._

### Frontend Flutter

```bash
# Executar no emulador/dispositivo Android ou iOS
docker-compose exec frontend flutter run

# Executar no Chrome
docker-compose exec frontend flutter run -d chrome
```

### Rebuild Rápido

Sempre que alterares o código do backend ou frontend e quiseres atualizar containers:

```bash
docker-compose up --build -d
```

---

## 📚 Funcionalidades Disponíveis

- Gestão completa de aulas privadas, em grupo e pacotes de aulas  
- Histórico de aulas e progresso dos alunos  
- Sistema de pagamentos (online e offline)  
- Gestão de escolas e respetivos serviços  
- Painéis administrativos para escolas e instrutores  
- Autenticação via Email, Google e Apple ID  

---

## 📄 Notas Importantes

- O backend online serve apenas para demonstração.  
- Para desenvolvimento local, este ambiente Docker isola todos os serviços.  
- Credenciais públicas: use apenas em ambiente de testes.  
- Futuras atualizações trarão novos módulos e melhorias.

---

## 📝 Autor & Orientação

- **Autor**: Francisco Sousa (a22301231)  
- **Orientador**: Prof. Lúcio Studer  
- **Coorientador**: Prof. Martim Mourão  
- **Curso**: Trabalho Final de Curso – Licenciatura em Engenharia Informática (ULHT)

---

⚡ **Última Atualização**: 27 de junho de 2025  
