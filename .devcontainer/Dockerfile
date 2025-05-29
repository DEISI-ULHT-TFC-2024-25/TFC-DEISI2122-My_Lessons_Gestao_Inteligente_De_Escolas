# .devcontainer/Dockerfile
FROM cirrusci/flutter:stable

USER root

# 1) Ensure HTTPS transport & certificates are available
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      apt-transport-https \
      ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# 2) Rewrite all Ubuntu repos to HTTPS
RUN sed -i \
      -e 's|http://archive.ubuntu.com/ubuntu|https://archive.ubuntu.com/ubuntu|g' \
      -e 's|http://security.ubuntu.com/ubuntu|https://security.ubuntu.com/ubuntu|g' \
    /etc/apt/sources.list

# 3) Update & install system deps (incl. python3-dev for Python.h)
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      python3-dev \
      python3-venv \
      python3-pip \
      build-essential \
      pkg-config \
      default-libmysqlclient-dev \
      libmysqlclient-dev \
 && rm -rf /var/lib/apt/lists/*

# 4) Create & activate virtualenv
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:${PATH}"

# 5) Pre-install Python deps
WORKDIR /workspace/mylessons_backend
COPY mylessons_backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

WORKDIR /workspace
EXPOSE 8000
