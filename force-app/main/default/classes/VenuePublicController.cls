/**
 * Experience Cloud Guest User(비로그인)가 호출하는 컨트롤러.
 * 인증은 Salesforce 로그인 세션/Org Sharing 규칙이 아니라 URL의 AccessToken__c 값 하나로 이루어진다.
 * 그래서 의도적으로 WITH USER_MODE/SECURITY_ENFORCED를 쓰지 않는다 — Guest User는 대부분 오브젝트에
 * Sharing 규칙상 접근 권한이 없어(OWD Private) USER_MODE를 걸면 토큰이 맞아도 결과가 0건으로 나온다.
 * 대신 모든 쿼리가 토큰으로 조회한 Lead.Id를 WHERE 절에 반드시 포함시켜(예: Lead__c = :l.Id)
 * "이 토큰 소유자의 데이터만" 접근 가능하도록 Apex 코드 자체가 접근 제어를 담당한다 — 32자 랜덤
 * 토큰(AccessTokenService)이 사실상의 비밀번호 역할을 한다.
 * Guest Profile에는 이 Apex 클래스에 대한 classAccesses(enabled=true)만 부여하면 되고,
 * 오브젝트/필드 CRUD는 시스템 모드로 실행되므로 별도 FLS 부여가 필요 없다.
 */
public without sharing class VenuePublicController {

    public class VenueRecommendationWrapper {
        @AuraEnabled public Id recommendationId;
        @AuraEnabled public Id venueId;
        @AuraEnabled public String venueName;
        @AuraEnabled public String district;
        @AuraEnabled public Decimal latitude;
        @AuraEnabled public Decimal longitude;
        @AuraEnabled public Decimal score;
        @AuraEnabled public Integer rankNumber;
        @AuraEnabled public String reasonText;
        @AuraEnabled public Boolean isSelected;
        @AuraEnabled public String venueTypeName;
    }

    @AuraEnabled(cacheable=true)
    public static List<VenueRecommendationWrapper> getRecommendations(String token) {
        Lead l = getLeadByToken(token);

        List<VenueRecommendationWrapper> results = new List<VenueRecommendationWrapper>();
        for (Recommendation__c rec : [
            SELECT Id, Rank__c, MatchScore__c, ReasonText__c, VenueNameSnapshot__c, Venue__c,
                   Venue__r.District__c, Venue__r.Coordinates__Latitude__s, Venue__r.Coordinates__Longitude__s,
                   Venue__r.VenueType__r.Name
            FROM Recommendation__c
            WHERE Lead__c = :l.Id AND RecommendationType__c = '장소'
            ORDER BY Rank__c ASC NULLS LAST
        ]) {
            VenueRecommendationWrapper w = new VenueRecommendationWrapper();
            w.recommendationId = rec.Id;
            w.venueId = rec.Venue__c;
            w.venueName = rec.VenueNameSnapshot__c;
            w.district = rec.Venue__r != null ? rec.Venue__r.District__c : null;
            w.latitude = rec.Venue__r != null ? rec.Venue__r.Coordinates__Latitude__s : null;
            w.longitude = rec.Venue__r != null ? rec.Venue__r.Coordinates__Longitude__s : null;
            w.score = rec.MatchScore__c;
            w.rankNumber = rec.Rank__c != null ? Integer.valueOf(rec.Rank__c) : null;
            w.reasonText = rec.ReasonText__c;
            w.isSelected = (l.SelectedVenueFromWeb__c != null && l.SelectedVenueFromWeb__c == rec.Venue__c);
            w.venueTypeName = rec.Venue__r != null ? rec.Venue__r.VenueType__r?.Name : null;
            results.add(w);
        }
        return results;
    }

    @AuraEnabled
    public static String submitDecision(String token, String actionType, Id recommendationId) {
        Lead l = getLeadByToken(token);

        if (actionType == 'CONFIRM') {
            if (recommendationId == null) {
                throw new AuraHandledException('확정할 장소를 선택해주세요.');
            }
            List<Recommendation__c> recs = [
                SELECT Venue__c FROM Recommendation__c
                WHERE Id = :recommendationId AND Lead__c = :l.Id
                LIMIT 1
            ];
            if (recs.isEmpty()) {
                throw new AuraHandledException('잘못된 요청입니다.');
            }
            l.SelectedVenueFromWeb__c = recs[0].Venue__c;
            l.Status = '결제 대기';
        } else if (actionType == 'VISIT') {
            l.Status = '답사 예정';
        } else if (actionType == 'RETRY') {
            l.Status = '재추천 요청';
        } else {
            throw new AuraHandledException('알 수 없는 요청입니다.');
        }

        update l;

        String emailDebugNote = '';
        if (actionType == 'CONFIRM') {
            emailDebugNote = sendPaymentInstructionEmail(l);
        }

        insert new Task(
            WhoId = l.Id,
            Subject = '[웹 응답] ' + actionType + ' - 확인 필요',
            ActivityDate = Date.today(),
            OwnerId = l.OwnerId,
            Status = 'Not Started',
            Description = emailDebugNote
        );

        return 'OK';
    }

    private static String sendPaymentInstructionEmail(Lead l) {
        if (String.isBlank(l.Email)) {
            return '결제 안내 이메일 미발송: Lead에 이메일 주소가 없음';
        }

        List<EmailTemplate> templates = [
            SELECT Id FROM EmailTemplate WHERE DeveloperName = 'Payment_Instruction_Email' LIMIT 1
        ];
        if (templates.isEmpty()) {
            return '결제 안내 이메일 미발송: Payment_Instruction_Email 템플릿이 없음';
        }

        // Messaging.sendEmail(SingleEmailMessage)의 하루 발송 한도(Developer Edition 기준 15건)는
        // 데모/테스트 중 금방 소진된다. MassEmailMessage는 별도의 하루 한도를 쓰므로 이걸로 발송해
        // 두 한도를 나눠서 쓴다 — 다만 MassEmailMessage는 본문을 직접 못 넣고 Email Template
        // (Payment_Instruction_Email, 머지필드로 장소명/패키지/계약금을 채움)을 통해서만 보낼 수 있다.
        // 어떤 이유로든 발송이 실패해도 예외가 밖으로 새어나가 CONFIRM/VISIT/RETRY 자체가
        // 실패하지 않도록 try/catch로 감싼다.
        try {
            Messaging.MassEmailMessage mail = new Messaging.MassEmailMessage();
            mail.setTemplateId(templates[0].Id);
            mail.setTargetObjectIds(new List<Id>{ l.Id });
            mail.setSaveAsActivity(true);

            List<Messaging.SendEmailResult> results = Messaging.sendEmail(new List<Messaging.MassEmailMessage>{ mail });
            if (results.isEmpty() || !results[0].isSuccess()) {
                String errMsg = '알 수 없는 오류';
                if (!results.isEmpty() && !results[0].getErrors().isEmpty()) {
                    errMsg = results[0].getErrors()[0].getMessage();
                }
                return '결제 안내 이메일 발송 실패: ' + errMsg;
            }
            return '결제 안내 이메일 발송 성공 (' + l.Email + ')';
        } catch (Exception ex) {
            return '결제 안내 이메일 발송 실패(예외): ' + ex.getMessage();
        }
    }

    private static Lead getLeadByToken(String token) {
        if (String.isBlank(token)) {
            throw new AuraHandledException('잘못된 접근입니다.');
        }
        List<Lead> leads = [
            SELECT Id, OwnerId, SelectedVenueFromWeb__c, Status, Email, FirstName, SelectedPackage__c
            FROM Lead
            WHERE AccessToken__c = :token
            LIMIT 1
        ];
        if (leads.isEmpty()) {
            throw new AuraHandledException('유효하지 않거나 만료된 링크입니다.');
        }
        return leads[0];
    }
}
