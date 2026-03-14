FROM eclipse-temurin:21-jdk-jammy

# Node.js 20 LTS (for frontend tooling / IntelliJ plugin builds)
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl ca-certificates gnupg && \
    mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | \
      gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" > \
      /etc/apt/sources.list.d/nodesource.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends nodejs && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Common build tools
RUN apt-get update && \
    apt-get install -y --no-install-recommends git unzip && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Pre-cache Gradle 9.0.0 for wrapper
RUN mkdir -p /root/.gradle/wrapper/dists/gradle-9.0.0-bin && \
    curl -fsSL https://services.gradle.org/distributions/gradle-9.0.0-bin.zip \
      -o /root/.gradle/wrapper/dists/gradle-9.0.0-bin/gradle-9.0.0-bin.zip && \
    cd /root/.gradle/wrapper/dists/gradle-9.0.0-bin && \
    unzip -q gradle-9.0.0-bin.zip && \
    rm gradle-9.0.0-bin.zip

# Maven 3.9.x
RUN curl -fsSL https://archive.apache.org/dist/maven/maven-3/3.9.9/binaries/apache-maven-3.9.9-bin.tar.gz | \
    tar -xz -C /opt && \
    ln -s /opt/apache-maven-3.9.9/bin/mvn /usr/local/bin/mvn

ENV MAVEN_HOME=/opt/apache-maven-3.9.9
