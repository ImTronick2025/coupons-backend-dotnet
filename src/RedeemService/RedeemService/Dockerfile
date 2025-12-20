FROM mcr.microsoft.com/dotnet/aspnet:10.0-preview AS base
WORKDIR /app
EXPOSE 8080

FROM mcr.microsoft.com/dotnet/sdk:10.0-preview AS build
WORKDIR /src
COPY ["RedeemService/RedeemService/RedeemService.csproj", "RedeemService/RedeemService/"]
COPY ["Shared/Shared.Models/Shared.Models.csproj", "Shared/Shared.Models/"]
RUN dotnet restore "RedeemService/RedeemService/RedeemService.csproj"
COPY . .
WORKDIR "/src/RedeemService/RedeemService"
RUN dotnet build "RedeemService.csproj" -c Release -o /app/build

FROM build AS publish
WORKDIR "/src/RedeemService/RedeemService"
RUN dotnet publish "RedeemService.csproj" -c Release -o /app/publish /p:UseAppHost=false

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "RedeemService.dll"]
