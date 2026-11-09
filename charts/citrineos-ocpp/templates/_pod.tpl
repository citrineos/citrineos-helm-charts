{{/* vim: set filetype=mustache: */}}
{{/*
Shared pod template (spec.template) for both Deployment and Rollout workloads.
Call with: (dict "root" $ "deployment" $deployment "name" $deploymentName)
`$` inside an included template is the dict above, NOT the chart root, so the
chart root is passed explicitly as .root and rebound to $root below.
*/}}
{{- define "citrineos-ocpp.podTemplate" -}}
{{- $root := .root }}
{{- $deployment := .deployment }}
{{- $deploymentName := .name }}
  template:
    metadata:
      labels:
        app: {{ include "citrineos-ocpp.name" $root }}
        component: {{ $deploymentName }}
        {{- include "citrineos-ocpp.selectorLabels" $root | nindent 8 }}
    spec:
      serviceAccountName: {{ include "citrineos-ocpp.serviceAccountName" $root }}
      terminationGracePeriodSeconds: {{ $deployment.terminationGracePeriodSeconds | default 60 }}
      securityContext:
        {{- toYaml $root.Values.podSecurityContext | nindent 8 }}
      containers:
        - name: {{ include "citrineos-ocpp.name" $root }}-{{ $deploymentName }}
          securityContext:
            {{- toYaml $root.Values.securityContext | nindent 12 }}
          image: "{{ $root.Values.global.image.repository }}:{{ $root.Values.global.image.tag }}"
          imagePullPolicy: {{ $root.Values.global.image.pullPolicy }}
          ports:
            - name: rest
              containerPort: {{ $deployment.service.ports.rest }}
            {{- if $deployment.service.ports.websocket1 }}
            - name: websocket1
              containerPort: {{ $deployment.service.ports.websocket1 }}
            {{- end }}
            {{- if $deployment.service.ports.websocket2 }}
            - name: websocket2
              containerPort: {{ $deployment.service.ports.websocket2 }}
            {{- end }}
            {{- if $deployment.service.ports.websocket3 }}
            - name: websocket3
              containerPort: {{ $deployment.service.ports.websocket3 }}
            {{- end }}
            {{- if $deployment.service.ports.websocket4 }}
            - name: websocket4
              containerPort: {{ $deployment.service.ports.websocket4 }}
            {{- end }}
            {{- if $deployment.service.ports.websocket5 }}
            - name: websocket5
              containerPort: {{ $deployment.service.ports.websocket5 }}
            {{- end }}
            - name: prometheus
              containerPort: {{ $deployment.service.ports.prometheus }}
          env:
            # Deployment-specific environment variables
            {{- range $key, $value := $deployment.env }}
            - name: {{ $key }}
              value: {{ $value | quote }}
            {{- end }}
            # Global shared environment variables
            {{- range $key, $value := $root.Values.global.sharedEnv }}
            - name: {{ $key }}
              value: {{ $value | quote }}
            {{- end }}
            # Environment variables from secrets
            {{- range $root.Values.global.sharedEnvFromSecretKeys }}
            - name: {{ .envName }}
              valueFrom:
                secretKeyRef:
                  name: {{ .secretName }}
                  key: {{ .secretKey }}
            {{- end }}
          resources:
            {{- toYaml $deployment.resources | nindent 12 }}
          {{- if and $deployment.lifecycle $deployment.lifecycle.preStopSleepSeconds }}
          lifecycle:
            preStop:
              exec:
                command:
                  - /bin/sh
                  - -c
                  - sleep {{ $deployment.lifecycle.preStopSleepSeconds }}
          {{- end }}
          {{- if and $deployment.probes.startup $deployment.probes.startup.enabled }}
          startupProbe:
            httpGet:
              path: {{ $deployment.probes.startup.path }}
              port: rest
            periodSeconds: {{ $deployment.probes.startup.periodSeconds | default 5 }}
            failureThreshold: {{ $deployment.probes.startup.failureThreshold | default 60 }}
            timeoutSeconds: {{ $deployment.probes.startup.timeoutSeconds | default 5 }}
          {{- end }}
          {{- if $deployment.probes.liveness.enabled }}
          livenessProbe:
            httpGet:
              path: {{ $deployment.probes.liveness.path }}
              port: rest
            {{- with $deployment.probes.liveness.initialDelaySeconds }}
            initialDelaySeconds: {{ . }}
            {{- end }}
            periodSeconds: {{ $deployment.probes.liveness.periodSeconds }}
            failureThreshold: {{ $deployment.probes.liveness.failureThreshold | default 3 }}
            timeoutSeconds: {{ $deployment.probes.liveness.timeoutSeconds | default 5 }}
          {{- end }}
          {{- if $deployment.probes.readiness.enabled }}
          readinessProbe:
            httpGet:
              path: {{ $deployment.probes.readiness.path }}
              port: rest
            {{- with $deployment.probes.readiness.initialDelaySeconds }}
            initialDelaySeconds: {{ . }}
            {{- end }}
            periodSeconds: {{ $deployment.probes.readiness.periodSeconds }}
            failureThreshold: {{ $deployment.probes.readiness.failureThreshold | default 3 }}
            timeoutSeconds: {{ $deployment.probes.readiness.timeoutSeconds | default 5 }}
          {{- end }}
          {{- with $deployment.extraVolumeMounts }}
          volumeMounts:
            {{- toYaml . | nindent 12 }}
          {{- end }}
      {{- with ($deployment.nodeSelector | default $root.Values.nodeSelector) }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with ($deployment.affinity | default $root.Values.affinity) }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with ($deployment.tolerations | default $root.Values.tolerations) }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with ($deployment.topologySpreadConstraints | default $root.Values.topologySpreadConstraints) }}
      topologySpreadConstraints:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with $deployment.extraVolumes }}
      volumes:
        {{- toYaml . | nindent 8 }}
      {{- end }}
{{- end }}
