<%--
  ~ Copyright (c) 2016, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
  ~
  ~  WSO2 Inc. licenses this file to you under the Apache License,
  ~  Version 2.0 (the "License"); you may not use this file except
  ~  in compliance with the License.
  ~  You may obtain a copy of the License at
  ~
  ~    http://www.apache.org/licenses/LICENSE-2.0
  ~
  ~ Unless required by applicable law or agreed to in writing,
  ~ software distributed under the License is distributed on an
  ~ "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
  ~ KIND, either express or implied.  See the License for the
  ~ specific language governing permissions and limitations
  ~ under the License.
  --%>
<%@ page contentType="text/html;charset=UTF-8" language="java" %>

<%@ page import="org.apache.commons.collections.map.HashedMap" %>
<%@ page import="org.apache.commons.lang.StringUtils" %>
<%@ page import="org.wso2.carbon.identity.mgt.endpoint.util.IdentityManagementEndpointConstants" %>
<%@ page import="org.wso2.carbon.identity.mgt.endpoint.util.IdentityManagementEndpointUtil" %>
<%@ page import="org.wso2.carbon.identity.mgt.endpoint.util.client.ApiException" %>
<%@ page import="org.wso2.carbon.identity.mgt.endpoint.util.client.api.UsernameRecoveryApi" %>
<%@ page import="org.wso2.carbon.identity.mgt.endpoint.util.client.model.Claim" %>
<%@ page import="org.wso2.carbon.identity.mgt.endpoint.util.client.model.UserClaim" %>
<%@ page import="org.wso2.carbon.identity.core.util.IdentityTenantUtil" %>
<%@ page import="java.util.ArrayList" %>
<%@ page import="java.util.List" %>
<%@ page import="java.util.Map" %>
<jsp:directive.include file="includes/localize.jsp"/>
<jsp:directive.include file="tenant-resolve.jsp"/>

<%
    boolean isPasswordRecoveryEmailConfirmation =
            Boolean.parseBoolean(request.getParameter("isPasswordRecoveryEmailConfirmation"));
    boolean isUsernameRecovery = Boolean.parseBoolean(request.getParameter("isUsernameRecovery"));

    // Common parameters for password recovery with email and self registration with email
    String username = request.getParameter("username");
    String sessionDataKey = request.getParameter("sessionDataKey");
    String confirmationKey = request.getParameter("confirmationKey");
    String callback = request.getParameter("callback");

    if (StringUtils.isBlank(callback)) {
        callback = IdentityManagementEndpointUtil.getUserPortalUrl(
                application.getInitParameter(IdentityManagementEndpointConstants.ConfigConstants.USER_PORTAL_URL));
    }

    // Password recovery parameters
    String recoveryOption = request.getParameter("recoveryOption");

    if (isUsernameRecovery) {
        // Username Recovery Scenario
        List<Claim> claims;
        UsernameRecoveryApi usernameRecoveryApi = new UsernameRecoveryApi();
        try {
            boolean isTenantQualifiedEndpointEnabled = IdentityTenantUtil.isTenantQualifiedUrlsEnabled();
            String resolvedTenant = null;
            if (isTenantQualifiedEndpointEnabled) {
                resolvedTenant = tenantDomain;
            }
            // If the config is not added, null will be passed as tenantDomain to maintain backward compatibility.
            claims = usernameRecoveryApi.getClaimsForUsernameRecovery(resolvedTenant, true);
        } catch (ApiException e) {
            IdentityManagementEndpointUtil.addErrorInformation(request, e);
            request.getRequestDispatcher("error.jsp").forward(request, response);
            return;
        }

        List<UserClaim> claimDTOList = new ArrayList<UserClaim>();

        for (Claim claimDTO : claims) {
            if (StringUtils.isNotBlank(request.getParameter(claimDTO.getUri()))) {
                UserClaim userClaim = new UserClaim();
                userClaim.setUri(claimDTO.getUri());
                userClaim.setValue(request.getParameter(claimDTO.getUri()).trim());
                claimDTOList.add(userClaim);
            }
        }

        try {
            Map<String, String> requestHeaders = new HashedMap();
            if (request.getParameter("g-recaptcha-response") != null) {
                requestHeaders.put("g-recaptcha-response", request.getParameter("g-recaptcha-response"));
            }
    
            usernameRecoveryApi.recoverUsernamePost(claimDTOList, tenantDomain, null, requestHeaders);
            request.setAttribute("callback", callback);
            request.setAttribute("tenantDomain", tenantDomain);
            request.getRequestDispatcher("username-recovery-complete.jsp").forward(request, response);
        } catch (ApiException e) {
            if (e.getCode() == 204) {
                request.setAttribute("error", true);
                request.setAttribute("errorMsg", IdentityManagementEndpointUtil.i18n(recoveryResourceBundle,
                        "No.valid.user.found"));
                request.getRequestDispatcher("recoveraccountrouter.do").forward(request, response);
                return;
            }

            IdentityManagementEndpointUtil.addErrorInformation(request, e);
            request.getRequestDispatcher("recoveraccountrouter.do").forward(request, response);
            return;
        }

    } else {
        request.setAttribute("sessionDataKey", sessionDataKey);
        
        if (isPasswordRecoveryEmailConfirmation) {
            session.setAttribute("username", username);
            session.setAttribute("confirmationKey", confirmationKey);
            request.setAttribute("callback", callback);
            request.getRequestDispatcher("password-reset.jsp").forward(request, response);
        } else {
            request.setAttribute("username", username);
            session.setAttribute("username", username);

            if (IdentityManagementEndpointConstants.PasswordRecoveryOptions.EMAIL.equals(recoveryOption)) {
                request.setAttribute("callback", callback);
                request.getRequestDispatcher("password-recovery-notify.jsp").forward(request, response);
            } else if (IdentityManagementEndpointConstants.PasswordRecoveryOptions.SECURITY_QUESTIONS
                    .equals(recoveryOption)) {
                request.setAttribute("callback", callback);
                request.getRequestDispatcher("challenge-question-request.jsp?username=" + username).forward(request,
                        response);
            } else {
                request.setAttribute("error", true);
                request.setAttribute("errorMsg", IdentityManagementEndpointUtil.i18n(recoveryResourceBundle,
                        "Unknown.password.recovery.option"));
                request.getRequestDispatcher("error.jsp").forward(request, response);
            }
        }
    }
%>
<html>
<head>
    <title></title>
</head>
<body>

</body>
</html>
