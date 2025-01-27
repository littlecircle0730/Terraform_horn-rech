import json

with open("/Users/hy.c/Desktop/ssm_parameters.json", "r") as f:
    ssm_data = json.load(f)

horn_rech_params = [
    param for param in ssm_data if param["Name"].startswith("/horn/rech")
]

env_lines = []
for param in horn_rech_params:
    env_key = param["Name"].replace("/horn/rech/", "")
    env_value = param["Value"]
    env_lines.append(f"{env_key}={env_value}")

with open(".env", "w") as f:
    f.write("\n".join(env_lines))

print(".env file updated successfully!")
