@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Export Data Interface View'
define root view entity ZI_EXPORT_DATA
  as select from zexport_data
{
  key export_id,
      created_by,
      created_at,
      last_changed_by, 
      last_changed_at,
      local_last_changed_at,
      filename,
      status,
      message
} 