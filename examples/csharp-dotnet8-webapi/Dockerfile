ARG BUILD_MODE=production

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

COPY src/CSharpWebApi/*.csproj ./CSharpWebApi/
RUN dotnet restore "./CSharpWebApi/CSharpWebApi.csproj"

COPY src/CSharpWebApi/. ./CSharpWebApi/
WORKDIR /src/CSharpWebApi

ARG BUILD_MODE
RUN if [ "$BUILD_MODE" = "debug" ]; then \
        dotnet publish "CSharpWebApi.csproj" -c Debug -o /app/publish /p:UseAppHost=false; \
    else \
        dotnet publish "CSharpWebApi.csproj" -c Release -o /app/publish /p:UseAppHost=false; \
    fi

FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS final
WORKDIR /app

ARG BUILD_MODE
ENV BUILD_MODE=${BUILD_MODE}

RUN if [ "$BUILD_MODE" = "debug" ]; then \
        apt-get update && \
        apt-get install -y curl unzip && \
        curl -sSL https://aka.ms/getvsdbgsh | bash /dev/stdin -v latest -l /vsdbg && \
        apt-get clean && \
        rm -rf /var/lib/apt/lists/*; \
    fi

COPY --from=build /app/publish .

EXPOSE 8080

ENV ASPNETCORE_URLS=http://+:8080
ENV ASPNETCORE_ENVIRONMENT=Development

ENTRYPOINT ["dotnet", "CSharpWebApi.dll"]