# Elasticsearch-index-status-inspector
A Bash script to monitor Elasticsearch indices: ILM phase, size, age, node location, and deletion suggestions.
______________________________________________________________________________________________________________

<div align="center" style="background:linear-gradient(-45deg,#005571,#00bfb3,#fab040,#ff6b6b);background-size:400% 400%;animation:gradientShift 12s ease infinite;padding:40px 20px;border-radius:12px;color:#fff;">
  <img src="https://cdn.jsdelivr.net/gh/devicons/devicon@latest/icons/elasticsearch/elasticsearch-original.svg" width="84" height="84" alt="Elasticsearch" style="filter:drop-shadow(0 4px 8px rgba(0,0,0,.2));"/>
  <h1 style="font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Helvetica,Arial,sans-serif;font-size:2.4em;margin:.2em 0 .3em;letter-spacing:.5px;">
    Elasticsearch Index Status Inspector
  </h1>
  <p style="font-size:1.1em;opacity:0.9;max-width:700px;">
    <strong>📊 A Bash CLI tool</strong> to monitor ILM phases, index size, age, node distribution & deletion candidates — right in your terminal.
  </p>

  <style>
    @keyframes gradientShift {
      0% { background-position: 0% 50%; }
      50% { background-position: 100% 50%; }
      100% { background-position: 0% 50%; }
    }
  </style>
</div>

---

<div align="center" style="margin: 30px 0; font-family: 'Courier New', 'monospace';">
  <div style="background-color: #0D1117; color: #C9D1D9; font-size: 14px; border-radius: 12px; box-shadow: 0 8px 24px rgba(0,0,0,0.3); max-width: 900px; overflow: hidden; margin: 0 auto; border: 1px solid #30363D;">
    
    <!-- Terminal Header -->
    <div style="background-color: #23272E; padding: 8px 12px; font-size: 12px; color: #B0B9C5; display: flex; align-items: center; gap: 8px;">
      <div style="width: 10px; height: 10px; background: #FF5F57; border-radius: 50%; display: inline-block;"></div>
      <div style="width: 10px; height: 10px; background: #FFBD2E; border-radius: 50%; display: inline-block;"></div>
      <div style="width: 10px; height: 10px; background: #28CA42; border-radius: 50%; display: inline-block;"></div>
      <span style="margin-left: 10px;">es-ilm-inspector.sh</span>
    </div>

    <!-- Terminal Body -->
    <div style="padding: 16px; line-height: 1.8; text-align: left; white-space: pre; font-family: 'Fira Code', 'Courier New', monospace; letter-spacing: 0;">
<span style="color: #79C0FF;">🔍 Elasticsearch Index Status Inspector</span>
Connected to: https://192.168.152.14:9200 (user: elastic)
Filter: filebeat-* | Threshold: 30 GB
------------------------------------------------------------------------

| Index                     | Phase | Age   | Size     | Note             | Hot Node       |
|---------------------------|-------|-------|----------|------------------|----------------|
| <span style="color: #F85149;">filebeat-2024.05.01</span>       | <span style="color: #F85149;">hot</span>   | 1d    | <span style="color: #F85149;">48.23 GB</span> | <span style="color: #F85149;">you can delete</span> | data-node-01   |
| <span style="color: #F85149;">filebeat-2024.05.02</span>       | <span style="color: #F85149;">hot</span>   | 2d    | <span style="color: #F85149;">45.10 GB</span> | <span style="color: #F85149;">you can delete</span> | data-node-02   |
| filebeat-2024.05.03       | <span style="color: #FD9800;">warm</span>  | 7d    | 38.45 GB |                  | data-node-03   |
| filebeat-2024.05.04       | <span style="color: #FD9800;">warm</span>  | 10d   | 32.00 GB |                  | data-node-01   |
| filebeat-2024.05.05       | <span style="color: #58A6FF;">cold</span>  | 25d   | 24.70 GB |                  | cold-node-01   |

> <span style="color: #79C0FF;">TOTAL:</span> 188.48 GB

💡 <span style="color: #79C0FF;">Delete command for top 3 large indices:</span>
curl -k -X DELETE "https://192.168.152.14:9200/filebeat-2024.05.01,filebeat-2024.05.02,filebeat-2024.05.03" -u elastic

------------------------------------------------------------------------
🖥️ Cluster Nodes Status
------------------------------------------------------------------------
ip            name         heap.percent ram.percent cpu load_1m load_5m load_15m role   master disk.used_percent uptime
192.168.152.11 node-1       65           70          8   1.2     1.0     0.9      di     *      68%             15d
192.168.152.12 node-2       58           67          6   0.9     1.1     1.0      di     -      72%             14d
192.168.152.13 node-3       45           50          4   0.7     0.8     0.7      di     -      55%             13d
    </div>
  </div>

  <p style="color: #666; font-size: 0.9em; margin-top: 16px;">
    Simulated output — real result in your terminal with colors & interactivity
  </p>
</div>
###################################################################################


# 🛠️ Elasticsearch-index-status-inspector


A powerful **Bash script** to monitor and manage your **Elasticsearch indices** — with live insights into **ILM phase**, **size**, **age**, **node distribution**, and **deletion recommendations**.

Perfect for DevOps, SREs, and Elastic Stack admins who need a quick terminal dashboard for index lifecycle management.


---

## ✨ Features

- 🔍 **Index filtering** by Beat type (`filebeat`, `winlogbeat`, etc.) or custom keyword
- 🌡️ **Color-coded ILM phases** (Hot 🟥, Warm 🟠, Cold 🔵)
- 📏 **Size in GB** with threshold-based deletion alerts
- 💻 **Hot node mapping** — see which nodes host each index
- ⏳ **Age tracking** — how old is each index?
- 🗑️ **Smart delete suggestions** for oversized indices
- 🖥️ **Cluster node status table** with alternating row colors
- 🔐 Supports **HTTPS + Basic Auth** (Elastic user/pass)

---

## 🚀 Quick Start

```bash
git clone https://github.com/alibeigi-amir/Elasticsearch-index-status-inspector.git
cd Elasticsearch-index-status-inspector
chmod +x es-index-status-inspector.sh
./es-index-status-inspector.sh
