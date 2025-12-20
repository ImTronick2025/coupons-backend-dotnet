FROM mcr.microsoft.com/dotnet/aspnet:10.0-preview AS base
WORKDIR /app
EXPOSE 8080

FROM mcr.microsoft.com/dotnet/sdk:10.0-preview AS build
WORKDIR /src
COPY ["CampaignService/CampaignService/CampaignService.csproj", "CampaignService/CampaignService/"]
COPY ["Shared/Shared.Models/Shared.Models.csproj", "Shared/Shared.Models/"]
RUN dotnet restore "CampaignService/CampaignService/CampaignService.csproj"
COPY . .
WORKDIR "/src/CampaignService/CampaignService"
RUN dotnet build "CampaignService.csproj" -c Release -o /app/build

FROM build AS publish
WORKDIR "/src/CampaignService/CampaignService"
RUN dotnet publish "CampaignService.csproj" -c Release -o /app/publish /p:UseAppHost=false

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "CampaignService.dll"]
