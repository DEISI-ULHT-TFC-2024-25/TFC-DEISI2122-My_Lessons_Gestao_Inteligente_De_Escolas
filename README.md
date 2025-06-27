# 🛹 My Lessons – Gestão Inteligente de Escolas

🔧 **Requisitos de Software**
- Python 3.11 ou superior (para backend)
- Flutter 3.x (para frontend)
- Git instalado
- Sistema operativo: Linux, macOS ou Windows

⚡ Esta é a **versão de desenvolvimento** do projeto **My Lessons**.
O repositório contém o código atualizado para demonstração e evolução da aplicação.
O backend encontra-se **hospedado** em [https://mylessons.pythonanywhere.com](https://mylessons.pythonanywhere.com), pelo que **não é necessário executar o servidor localmente**.
No entanto, para efeitos de desenvolvimento local, os comandos encontram-se indicados mais abaixo.

---

🏗️ **Visão Geral do Projeto**

O **My Lessons** é uma aplicação digital criada para apoiar a gestão administrativa e operacional de escolas desportivas, escolas de música e centros de explicações.

Funcionalidades principais:
- Gestão de Aulas Privadas e em Grupo
- Gestão de Pagamentos e Modalidades de Pagamento
- Acompanhamento de Progresso dos Alunos
- Comunicação e Notificações In-App

---

🌐 **Acesso Online**
- **Backend Web**:  
  [https://mylessons.pythonanywhere.com](https://mylessons.pythonanywhere.com)

  **Credenciais de Teste**:
  - Username: `admin`
  - Password: `password`

- **Aplicação iOS via TestFlight**:  
  [Aceder ao TestFlight](https://testflight.apple.com/join/NUZAbPqm)

---

🔄 **Clonar o Projeto**

```bash
git clone https://github.com/DEISI-ULHT-TFC-2024-25/TFC-DEISI-AlunoG2122-My-Lessons-Gestao-Inteligente-de-Escolas.git
cd TFC-DEISI-AlunoG2122-My-Lessons-Gestao-Inteligente-de-Escolas
```

---

🛠️ **Instalar Dependências**

**Frontend Flutter**:
```bash
flutter pub get
```

**Backend Django (opcional – apenas para desenvolvimento local)**:
```bash
python -m venv venv
source venv/bin/activate  # Linux/Mac
venv\Scripts\activate  # Windows

pip install -r requirements.txt
```

---

🚀 **Executar Localmente**

**Nota**:  
O backend encontra-se hospedado online. **Não é necessário** correr o backend localmente para testar a aplicação.

**Se desejar correr o backend localmente para desenvolvimento/testes**:
```bash
python manage.py runserver
```

**Para correr o frontend Flutter**:
```bash
flutter run
```

---

📚 **Funcionalidades Disponíveis**
- Gestão completa de aulas privadas, em grupo e pacotes de aulas
- Histórico de aulas e gestão de progresso dos alunos
- Sistema de pagamentos (online e offline)
- Gestão de escolas e respetivos serviços
- Painéis administrativos para escolas e instrutores
- Autenticação via email, Google e Apple ID

---

📄 **Notas Importantes**
- O backend atual destina-se apenas a desenvolvimento e testes.
- As credenciais fornecidas são públicas para efeitos de demonstração.
- A aplicação continuará a ser expandida com novos módulos no futuro.

---

📝 **Autor**
- **Francisco Sousa** – a22301231

**Orientador**:  
- **Prof. Lúcio Studer**

**Coorientador**:  
- **Prof. Martim Mourão**

**Curso**:  
- Trabalho Final de Curso – Licenciatura em Engenharia Informática  
- Universidade Lusófona – ULHT  

---

⚡ **Última Atualização**: abril de 2025
