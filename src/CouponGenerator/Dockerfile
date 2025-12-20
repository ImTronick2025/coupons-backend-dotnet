# Build stage
FROM mcr.microsoft.com/dotnet/sdk:10.0-preview AS build
WORKDIR /src

COPY ["src/CouponGenerator/CouponGenerator/CouponGenerator.csproj", "CouponGenerator/"]
RUN dotnet restore "CouponGenerator/CouponGenerator.csproj"

COPY src/CouponGenerator/CouponGenerator/ CouponGenerator/
WORKDIR /src/CouponGenerator
RUN dotnet build "CouponGenerator.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "CouponGenerator.csproj" -c Release -o /app/publish /p:UseAppHost=false

# Runtime stage
FROM mcr.microsoft.com/dotnet/runtime:10.0-preview AS final
WORKDIR /app

COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "CouponGenerator.dll"]
