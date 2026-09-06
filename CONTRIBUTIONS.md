# 기여 명세

**개인 프로젝트.** Salesforce AFDX Agentforce Testdrive 스타터 템플릿 org 위에 구축했으며,
아래 컴포넌트는 전부 직접 설계·구현한 것입니다. 템플릿 기본 컴포넌트(WeatherService·CheckWeather·CurrentDate 등 Coral Cloud 데모용)는 제외했습니다.
AI 협업 도구를 사용했고 설계·의사결정·검증은 직접 수행했습니다.

## 커스텀 오브젝트
- `Venue__c` — 필드 15개
- `VenueType__c` — 필드 3개
- `WeddingPackage__c` — 필드 3개
- `Recommendation__c` — 필드 12개
- `Lead` (표준) — 커스텀 필드 14개
- `Opportunity` (표준) — `ConfirmedVenue__c` 필드 + `Wedding_Concierge` Record Type / Business Process

## Apex
- `VenuePublicController`
- `LeadConversionService`
- `AccessTokenService`
- 테스트: `VenuePublicControllerTest` · `LeadConversionServiceTest`

## Flow
- `Wedding_Concierge_Recommendation` (Screen Flow — 조건입력 → 개인화 점수 → TOP 3 → 이메일)
- `Set_Default_Wedding_Stage`

## LWC
- `venueRecommendationMap` — 추천 장소 지도

## 기타
- App `Wedding_Concierge` · Path Assistant · Permission Set `Concierge_CRM_Perms`
- Lead Assignment Rule · Quick Action 2종 · Experience Cloud 사이트(`Wedding Recs`) + `VenuePublicController`
- `web-to-lead/` — Setup 마법사 대신 직접 작성한 HTML 폼 + 썸네일 이미지
