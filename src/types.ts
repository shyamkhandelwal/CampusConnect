export const categories = ['Electronics','IDs & Cards','Keys','Bags & Backpacks','Clothing','Books & Stationery','Bottles & Accessories','Wallets & Personal Items','Other'] as const;
export type Category = typeof categories[number];
export type ListingType = 'lost' | 'found';
export type ListingStatus = 'open' | 'claim_pending' | 'reunited';
export type ClaimStatus = 'pending' | 'approved' | 'rejected';
export interface Listing {
  id:string; ownerId:string; title:string; type:ListingType; category:Category; location:string; itemDate:string;
  description:string; image:string|null; createdAt:string; status:ListingStatus; reporter:string; contactPreference:string;
}
export interface Claim {
  id:string; listingId:string; claimantId:string; claimantName:string; explanation:string; details:string; message:string;
  status:ClaimStatus; createdAt:string;
}
export interface ListingReport { id:string; listingId:string; reason:string; createdAt:string; reporterId:string }
export interface Dataset { listings:Listing[]; claims:Claim[]; reports:ListingReport[] }
