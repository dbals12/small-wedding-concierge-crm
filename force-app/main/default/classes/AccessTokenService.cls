public with sharing class AccessTokenService {

    @TestVisible
    private static final Integer TOKEN_VALID_DAYS = 7;

    @InvocableMethod(label='Generate Access Token' description='Lead에 URL 노출용 랜덤 접근 토큰을 발급하고 AccessToken__c에 저장한다. 레코드 Id를 그대로 URL에 노출하지 않기 위한 별도의 추측 불가능한 값.')
    public static List<String> generateTokens(List<Id> leadIds) {
        List<String> tokens = new List<String>();
        List<Lead> toUpdate = new List<Lead>();

        for (Id leadId : leadIds) {
            String token = EncodingUtil.convertToHex(Crypto.generateAesKey(128)).substring(0, 32);
            tokens.add(token);
            toUpdate.add(new Lead(
                Id = leadId,
                AccessToken__c = token,
                AccessTokenExpiresAt__c = System.now().addDays(TOKEN_VALID_DAYS)
            ));
        }

        update toUpdate;
        return tokens;
    }
}
