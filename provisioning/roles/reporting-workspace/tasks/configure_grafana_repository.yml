- name: Ensure Grafana repository GPG key is installed
  when: grafana_repository.apt_key is defined
  ansible.builtin.apt_key:
    state: "{{ grafana_repository.apt_key.state | default('present') }}"
    url: "{{ grafana_repository.apt_key.url | default(omit) }}"
    id: "{{ grafana_repository.apt_key.id | default(omit) }}"
    keyserver: "{{ grafana_repository.apt_key.keyserver | default(omit) }}"
    keyring: "{{ grafana_repository.apt_key.keyring | default(omit) }}"

- name: Configure Grafana package repository
  when: grafana_repository.apt_repository is defined
  ansible.builtin.apt_repository:
    repo: "{{ grafana_repository.apt_repository.repo }}"
    filename: "{{ grafana_repository.apt_repository.filename | default(omit) }}"
    state: "{{ grafana_repository.apt_repository.state | default('present') }}"
    mode: "{{ grafana_repository.apt_repository.mode | default(omit) }}"
    update_cache: "{{ grafana_repository.apt_repository.update_cache | default(omit) }}"
