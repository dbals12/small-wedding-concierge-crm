public with sharing class LeadConversionService {

    private static final Map<String, String> PACKAGE_TO_RECORD_TYPE_DEV_NAME = new Map<String, String>{
        '베이직' => 'Basic_Package',
        '스탠다드' => 'Standard_Package',
        '프리미엄' => 'Wedding_Concierge'
    };

    @InvocableMethod(label='Convert Lead With Package' description='SelectedPackage__c에 맞는 Opportunity Record Type으로 Lead를 전환한다. 장소 확정(SelectedVenueFromWeb__c)과 계약금 입금 확인(PaymentConfirmed__c)이 모두 되어 있어야 전환된다.')
    public static List<String> convertLeadsWithPackage(List<Id> leadIds) {
        List<String> results = new List<String>();
        Map<String, Id> recordTypeIdByDevName = getOpportunityRecordTypeIds();

        List<Lead> leads = [
            SELECT Id, FirstName, LastName, SelectedPackage__c, SelectedVenueFromWeb__c, PaymentConfirmed__c
            FROM Lead
            WHERE Id IN :leadIds
        ];

        for (Lead l : leads) {
            if (!l.PaymentConfirmed__c) {
                results.add('전환 실패: 계약금 입금 확인이 되지 않았습니다.');
                continue;
            }
            if (l.SelectedVenueFromWeb__c == null) {
                results.add('전환 실패: 확정된 장소가 없습니다.');
                continue;
            }

            String rtDevName = PACKAGE_TO_RECORD_TYPE_DEV_NAME.get(l.SelectedPackage__c);
            if (rtDevName == null) {
                rtDevName = 'Standard_Package';
            }
            Id targetRecordTypeId = recordTypeIdByDevName.get(rtDevName);

            Database.LeadConvert lc = new Database.LeadConvert();
            lc.setLeadId(l.Id);
            lc.setConvertedStatus('Closed - Converted');
            lc.setDoNotCreateOpportunity(false);
            lc.setOpportunityName(l.LastName + l.FirstName + ' 웨딩 - ' + l.SelectedPackage__c + ' 패키지');

            Database.LeadConvertResult lcr = Database.convertLead(lc);

            if (!lcr.isSuccess()) {
                results.add('전환 실패: ' + lcr.getErrors()[0].getMessage());
                continue;
            }

            // Database.LeadConvert에는 Opportunity Record Type을 지정하는 API가 없어(공식적으로 확인됨),
            // 전환 직후 별도 업데이트로 패키지에 맞는 Record Type/Stage/확정 장소를 재설정한다.
            update new Opportunity(
                Id = lcr.getOpportunityId(),
                RecordTypeId = targetRecordTypeId,
                StageName = '장소 확정',
                ConfirmedVenue__c = l.SelectedVenueFromWeb__c
            );

            results.add('전환 성공: ' + lcr.getOpportunityId());
        }

        return results;
    }

    private static Map<String, Id> getOpportunityRecordTypeIds() {
        Map<String, Id> result = new Map<String, Id>();
        for (RecordType rt : [SELECT Id, DeveloperName FROM RecordType WHERE SObjectType = 'Opportunity']) {
            result.put(rt.DeveloperName, rt.Id);
        }
        return result;
    }
}
