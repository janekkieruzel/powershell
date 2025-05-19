Connect-ExchangeOnline
#Import
#Add-DistributionGroupMember -Identity "group1@example.com" -Member "user1@example.com"
#Add-UnifiedGroupLinks -Identity "group2@example.com" -LinkType Member -Links "user2@example.com"
Set-UnifiedGroup "group3@example.com" -UnifiedGroupWelcomeMessageEnabled:$false