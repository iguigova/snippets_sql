using email2.Utils;
using SvrCommon;
using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;

namespace email2.Server.Data
{
    public class CdaRules
    {
        private const string RulesLogFileId = "rules";

        public static List<CRule> GetRules(string tag = null)
        {
            var rules = new List<CRule>();

            SqlDataReader drData = null;
            try
            {
                drData = CSql.ExecuteReader(CSql.conStr, CommandType.StoredProcedure, "spGetRules", GetTagParameter(tag));

                if (drData != null && drData.HasRows)
                {
                    while (drData.Read())
                    {
                        var rule = new CRule();         
               
                        rule.RuleDefinitionId = (int)drData["id"];
                        rule.EmailSubject = drData["email_subject"].ToString();
                        rule.EmailBody = drData["email_body"].ToString();
						rule.EmailBodyAltText = drData["email_body_alttext"].ToString();
						rule.Formula = drData["formula"].ToString();
						rule.Type = drData["type"].ToString();
                        rule.Parameters = GetRuleSqlParameters((int)drData["params_offset"], drData);

                        rules.Add(rule);
                    }
                }
            }
            catch (Exception ex)
            {
                CLog.Log(ex);
                CLog.Log(ex.Message, RulesLogFileId);
            }
            finally
            {
                if (drData != null && !drData.IsClosed)
                {
                    drData.Close();
                }
            }

            CLog.Log(string.Format("Found {0} active rules.", rules.Count), RulesLogFileId);
            return rules;
        }

        public static List<CRuleEmail> ParseRule(CRule rule)
        {
            var ruleEmails = new List<CRuleEmail>();

            SqlDataReader drData = null;
            try
            {
				drData = CSql.ExecuteReader(CSql.conStr, (CommandType)Enum.Parse(typeof(CommandType), rule.Type), rule.Formula, rule.Parameters.ToArray());
                
                if (drData != null && drData.HasRows)
                {
                    while (drData.Read())
                    {
                        var ruleEmail = new CRuleEmail();

                        ruleEmail.ServiceGuid = drData["service_guid"].ToString();
                        ruleEmail.To = drData["email_address"].ToString();
						ruleEmail.Subject = rule.EmailSubject;
						ruleEmail.Body = rule.EmailBody;
						ruleEmail.BodyAltText = rule.EmailBodyAltText;
                        ruleEmail.Data = GetData(drData);

                        ruleEmails.Add(ruleEmail);
                    }
                }
            }
            catch (Exception ex)
            {
                CLog.Log(ex);
                CLog.Log(ex.Message, RulesLogFileId);
            }
            finally
            {
                if (drData != null && !drData.IsClosed)
                {
                    drData.Close();
                }
            }

            CLog.Log(string.Format("For rule {0} - {1}: sending {2} emails.", rule.RuleDefinitionId, rule.Formula, ruleEmails.Count), RulesLogFileId);
            return ruleEmails;
        }

        private static string GetRuleSqlParameterName(int idx)
        {
            return string.Format("param{0}", idx);
        }

        private static SqlParameter BuildRuleSqlParameter(int idx, string data)
        {
            var param_defn = data.Split(',');
            var param_value = param_defn[0];
            var param_type = (SqlDbType)Enum.Parse(typeof(SqlDbType), param_defn[1]);

            var param = new SqlParameter(GetRuleSqlParameterName(idx), param_type);
            param.Value = param_value;

            return param;
        }

        private static List<SqlParameter> GetRuleSqlParameters(int idx, SqlDataReader reader)
        {
            var parameters = new List<SqlParameter>();

			var offset = idx; 
            var data = reader[idx];

            while (data != null && !string.IsNullOrEmpty(data.ToString()))
            {
                parameters.Add(BuildRuleSqlParameter(idx - offset + 1, data.ToString()));
                data = reader[++idx];
            }

            return parameters;
        }

        private static SqlParameter GetTagParameter(string tag)
        {
            var rTag = new SqlParameter("@Tag", SqlDbType.NVarChar, 1000);

            if (string.IsNullOrEmpty(tag))
            {
                rTag.Value = DBNull.Value;
            }
            else
            {
                rTag.Value = tag;
            }

            return rTag;
        }

        private static CEncoding GetData(SqlDataReader reader)
        {
            var data = new CEncoding();

            for (var i = 0; i < reader.FieldCount; i++)
            {
                data.SetValue(reader.GetName(i), reader[i].ToString());
            }

            return data;
        }
    }
}
