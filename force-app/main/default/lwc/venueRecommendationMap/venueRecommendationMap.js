import { LightningElement, api, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import getRecommendations from '@salesforce/apex/VenuePublicController.getRecommendations';
import submitDecision from '@salesforce/apex/VenuePublicController.submitDecision';
import weddingHallImg1 from '@salesforce/resourceUrl/VenueTypeWeddingHall1';
import weddingHallImg2 from '@salesforce/resourceUrl/VenueTypeWeddingHall2';
import weddingHallImg3 from '@salesforce/resourceUrl/VenueTypeWeddingHall3';
import weddingHallImg4 from '@salesforce/resourceUrl/VenueTypeWeddingHall4';
import weddingHallImg5 from '@salesforce/resourceUrl/VenueTypeWeddingHall5';
import weddingHallImg6 from '@salesforce/resourceUrl/VenueTypeWeddingHall6';
import weddingHallImg7 from '@salesforce/resourceUrl/VenueTypeWeddingHall7';
import restaurantImg1 from '@salesforce/resourceUrl/VenueTypeRestaurant1';
import restaurantImg2 from '@salesforce/resourceUrl/VenueTypeRestaurant2';
import restaurantImg3 from '@salesforce/resourceUrl/VenueTypeRestaurant3';
import restaurantImg4 from '@salesforce/resourceUrl/VenueTypeRestaurant4';
import restaurantImg5 from '@salesforce/resourceUrl/VenueTypeRestaurant5';
import cafeImg1 from '@salesforce/resourceUrl/VenueTypeCafe1';
import cafeImg2 from '@salesforce/resourceUrl/VenueTypeCafe2';
import cafeImg3 from '@salesforce/resourceUrl/VenueTypeCafe3';
import cafeImg4 from '@salesforce/resourceUrl/VenueTypeCafe4';
import cafeImg5 from '@salesforce/resourceUrl/VenueTypeCafe5';
import cafeImg6 from '@salesforce/resourceUrl/VenueTypeCafe6';
import cafeImg7 from '@salesforce/resourceUrl/VenueTypeCafe7';
import outdoorImg1 from '@salesforce/resourceUrl/VenueTypeOutdoor1';
import outdoorImg2 from '@salesforce/resourceUrl/VenueTypeOutdoor2';
import outdoorImg3 from '@salesforce/resourceUrl/VenueTypeOutdoor3';

const NAME_PREFIX_PATTERN = /^\[(데모|가상)\]\s*/;
const VENUE_TYPE_IMAGES = {
    웨딩홀: [weddingHallImg1, weddingHallImg2, weddingHallImg3, weddingHallImg4, weddingHallImg5, weddingHallImg6, weddingHallImg7],
    레스토랑: [restaurantImg1, restaurantImg2, restaurantImg3, restaurantImg4, restaurantImg5],
    카페: [cafeImg1, cafeImg2, cafeImg3, cafeImg4, cafeImg5, cafeImg6, cafeImg7],
    야외: [outdoorImg1, outdoorImg2, outdoorImg3]
};

function shuffle(array) {
    const copy = array.slice();
    for (let i = copy.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        [copy[i], copy[j]] = [copy[j], copy[i]];
    }
    return copy;
}

// 한 번의 결과 로드 안에서는 같은 유형이라도 서로 다른 사진이 나오도록,
// 유형별로 섞은 큐에서 순서대로 꺼내 쓰고 다 쓰면 다시 섞어서 이어간다.
class ImagePicker {
    constructor() {
        this.queues = {};
    }
    next(venueTypeName) {
        const options = VENUE_TYPE_IMAGES[venueTypeName];
        if (!options || options.length === 0) {
            return null;
        }
        if (!this.queues[venueTypeName] || this.queues[venueTypeName].length === 0) {
            this.queues[venueTypeName] = shuffle(options);
        }
        return this.queues[venueTypeName].pop();
    }
}

export default class VenueRecommendationMap extends LightningElement {
    @api token;
    isLoading = true;
    errorMessage;
    recommendations = [];
    feedbackMessage;
    view = 'LOADING'; // LOADING | RESULTS | ERROR | DONE
    selectedRecommendationId;

    @wire(CurrentPageReference)
    getPageReference(pageRef) {
        if (pageRef && pageRef.state && pageRef.state.token) {
            this.token = pageRef.state.token;
            this.loadRecommendations();
        } else if (pageRef && !this.token) {
            this.view = 'ERROR';
            this.errorMessage = '잘못된 접근입니다. 이메일에 있는 링크를 다시 확인해주세요.';
            this.isLoading = false;
        }
    }

    async loadRecommendations() {
        this.isLoading = true;
        try {
            const raw = await getRecommendations({ token: this.token });
            const imagePicker = new ImagePicker();
            this.recommendations = raw.map((r) => this.buildCard(r, imagePicker));
            this.view = 'RESULTS';
        } catch (e) {
            this.view = 'ERROR';
            this.errorMessage = (e && e.body && e.body.message) || '추천 결과를 불러오지 못했습니다.';
        } finally {
            this.isLoading = false;
        }
    }

    buildCard(r, imagePicker) {
        const cleanName = (r.venueName || '').replace(NAME_PREFIX_PATTERN, '');
        const hasLocation = r.latitude != null && r.longitude != null;
        const imageUrl = imagePicker.next(r.venueTypeName);
        return {
            ...r,
            venueName: cleanName,
            isDemoData: r.isDemoData,
            medal: r.rankNumber === 1 ? '🥇' : r.rankNumber === 2 ? '🥈' : '🥉',
            hasLocation,
            reasonBullets: this.toBullets(r.reasonText),
            naverMapUrl: `https://map.naver.com/v5/search/${encodeURIComponent(cleanName)}`,
            imageUrl,
            hasImage: imageUrl != null,
            cardClass: 'venue-card'
        };
    }

    toBullets(reasonText) {
        if (!reasonText) {
            return [];
        }
        return reasonText
            .split(',')
            .map((part) => part.trim())
            .filter((part) => part.length > 0)
            .map((text, index) => ({ id: index, text }));
    }

    get mapMarkers() {
        return this.recommendations
            .filter((r) => r.hasLocation)
            .map((r) => ({
                location: {
                    Latitude: r.latitude,
                    Longitude: r.longitude,
                    Street: `${r.venueName} · ${r.district || ''}`
                },
                title: `${r.medal} ${r.venueName}`,
                description: `매칭 ${r.score}점`,
                value: r.recommendationId
            }));
    }

    handleMarkerSelect(event) {
        const selectedId = event.detail.selectedMarkerValue;
        this.selectedRecommendationId = selectedId;
        this.recommendations = this.recommendations.map((r) => ({
            ...r,
            cardClass: r.recommendationId === selectedId ? 'venue-card venue-card_selected' : 'venue-card'
        }));
    }

    get hasMarkers() {
        return this.mapMarkers.length > 0;
    }

    get isLoadingView() {
        return this.view === 'LOADING' && this.isLoading;
    }

    get isResultsView() {
        return this.view === 'RESULTS';
    }

    get isErrorView() {
        return this.view === 'ERROR';
    }

    get isDoneView() {
        return this.view === 'DONE';
    }

    async handleConfirm(event) {
        const recommendationId = event.target.dataset.id;
        await this.submit('CONFIRM', recommendationId, '선택하신 장소로 진행을 도와드릴게요. 결제 안내를 곧 보내드립니다.');
    }

    async handleVisit() {
        await this.submit('VISIT', null, '답사 일정 조율을 위해 담당자가 곧 연락드릴게요.');
    }

    async handleRetry() {
        await this.submit('RETRY', null, '새로운 조건으로 다시 추천해드릴게요. 담당자가 확인 연락 드립니다.');
    }

    async submit(actionType, recommendationId, message) {
        this.isLoading = true;
        try {
            await submitDecision({ token: this.token, actionType, recommendationId });
            this.feedbackMessage = message;
            this.view = 'DONE';
        } catch (e) {
            this.errorMessage = (e && e.body && e.body.message) || '요청 처리 중 오류가 발생했습니다.';
            this.view = 'ERROR';
        } finally {
            this.isLoading = false;
        }
    }
}
