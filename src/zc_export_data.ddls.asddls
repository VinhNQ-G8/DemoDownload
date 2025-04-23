@EndUserText.label: 'Export Data Consumption View'
@AccessControl.authorizationCheck: #CHECK
@Metadata.allowExtensions: true
@Search.searchable: true
define root view entity ZC_EXPORT_DATA
  provider contract transactional_query
  as projection on ZI_EXPORT_DATA
{
  key export_id,
      @Semantics.user.createdBy: true
      created_by,
      @Semantics.systemDateTime.createdAt: true  
      created_at,
      @Semantics.user.lastChangedBy: true
      last_changed_by,
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at,
      filename,
      status,
      message
} 