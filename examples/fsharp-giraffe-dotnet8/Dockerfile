ARG BUILD_MODE=production

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

COPY src/FSharpGiraffe/*.fsproj ./FSharpGiraffe/
RUN dotnet restore "./FSharpGiraffe/FSharpGiraffe.fsproj"

COPY src/FSharpGiraffe/. ./FSharpGiraffe/
WORKDIR /src/FSharpGiraffe

ARG BUILD_MODE
RUN if [ "$BUILD_MODE" = "debug" ]; then \
        dotnet publish "FSharpGiraffe.fsproj" -c Debug -o /app/publish /p:UseAppHost=false; \
    else \
        dotnet publish "FSharpGiraffe.fsproj" -c Release -o /app/publish /p:UseAppHost=false; \
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

ENTRYPOINT ["dotnet", "FSharpGiraffe.dll"]