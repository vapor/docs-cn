# 使用Nginx进行部署

Nginx是一个非常快的、经过测试的、易于配置的HTTP服务器和代理。虽然Vapor支持直接为带有或不带有TLS的HTTP请求提供服务，但在Nginx后面进行代理可以提供更高的性能、安全性和易用性。

!!! note
    我们建议在Nginx后面代理Vapor HTTP服务器。

## 概述

代理一个HTTP服务器是什么意思？简而言之，代理在公共互联网和你的HTTP服务器之间充当中间人。请求来到代理，然后将它们发送到Vapor。

这个中间人代理的一个重要特点是，它可以改变甚至重定向请求。例如，代理可以要求客户使用TLS（https），限制请求的速率，甚至可以不与你的Vapor应用程序交谈而提供公共文件。

![nginx-proxy](https://cloud.githubusercontent.com/assets/1342803/20184965/5d9d588a-a738-11e6-91fe-28c3a4f7e46b.png)

### 更多细节

接收HTTP请求的默认端口是`80`端口（HTTPS为`443`）。当你将Vapor服务器绑定到`80`端口时，它将直接接收并响应到你的服务器上的HTTP请求。当添加像Nginx这样的代理时，你将Vapor绑定到一个内部端口，如端口`8080`。

!!! note
    大于1024的端口不需要`sudo`来绑定。

当Vapor被绑定到`80`或`443`以外的端口时，它将不能被外部互联网访问。然后，将Nginx绑定到`80`端口，并将其配置为将请求路由到Vapor服务器的`8080`端口（或你选择的任何一个端口）。

就这样了。如果Nginx配置正确，你会看到Vapor应用程序对`80`端口的请求进行响应。Nginx代理的请求和响应是不可见的。

## 安装Nginx

第一步是安装Nginx。Nginx的一个伟大之处在于它有大量的社区资源和文档。正因为如此，我们不会在这里详细介绍Nginx的安装，因为几乎肯定会有针对你的特定平台、操作系统和供应商的教程。

教程：

- [如何在Ubuntu 20.04上安装Nginx](https://www.digitalocean.com/community/tutorials/how-to-install-nginx-on-ubuntu-20-04)
- [如何在Ubuntu 18.04上安装Nginx](https://www.digitalocean.com/community/tutorials/how-to-install-nginx-on-ubuntu-18-04)
- [如何在CentOS 8上安装Nginx](https://www.digitalocean.com/community/tutorials/how-to-install-nginx-on-centos-8)
- [如何在Ubuntu 16.04上安装Nginx](https://www.digitalocean.com/community/tutorials/how-to-install-nginx-on-ubuntu-16-04)
- [如何在Heroku上部署Nginx](https://blog.codeship.com/how-to-deploy-nginx-on-heroku/)

### 软件包管理器

Nginx可以通过Linux上的软件包管理器进行安装。

#### Ubuntu

```sh
sudo apt-get update
sudo apt-get install nginx
```

#### CentOS和Amazon Linux

```sh
sudo yum install nginx
```

#### Fedora

```sh
sudo dnf install nginx
```

### 验证安装

通过在浏览器中访问服务器的IP地址，检查Nginx是否被正确安装

```
http://server_domain_name_or_IP
```

### 服务

该服务可以被启动或停止。

```sh
sudo service nginx stop
sudo service nginx start
sudo service nginx restart
```

## 启动Vapor

Nginx可以通过`sudo service nginx...`命令来启动和停止。你将需要类似的东西来启动和停止Vapor服务器。

有很多方法可以做到这一点，它们取决于你要部署到哪个平台。查看[Supervisor](supervisor.md)说明，添加启动和停止Vapor应用程序的命令。

## 配置代理

启用站点的配置文件可以在`/etc/nginx/sites-enabled/`中找到。

创建一个新的文件或复制`/etc/nginx/sites-available/`中的例子模板来开始使用。

下面是一个在主目录下名为`Hello`的Vapor项目的配置文件例子。

```sh
server {
    server_name hello.com;
    listen 80;

    root /home/vapor/Hello/Public/;

    location @proxy {
        proxy_pass http://127.0.0.1:8080;
        proxy_pass_header Server;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_pass_header Server;
        proxy_connect_timeout 3s;
        proxy_read_timeout 10s;
    }
}
```

这个配置文件假设`Hello`项目在生产模式下启动时绑定到端口`8080`。

### 服务文件

Nginx也可以在不询问Vapor应用程序的情况下提供公共文件。这可以通过释放Vapor进程来提高性能，使其在重载下执行其他任务。

```sh
server {
	...

    # 通过nginx提供所有的公共/静态文件，其余的退到Vapor。
	location / {
		try_files $uri @proxy;
	}

	location @proxy {
		...
	}
}
```

### TLS

只要正确地生成了证书，添加TLS是相对简单的。要免费生成TLS证书，请查看[Let's Encrypt](https://letsencrypt.org/getting-started/)。

```sh
server {
    ...

    listen 443 ssl;

    ssl_certificate /etc/letsencrypt/live/hello.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/hello.com/privkey.pem;

    ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
    ssl_prefer_server_ciphers on;
    ssl_dhparam /etc/ssl/certs/dhparam.pem;
    ssl_ciphers 'ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-DSS-AES128-GCM-SHA256:kEDH+AESGCM:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-DSS-AES128-SHA256:DHE-RSA-AES256-SHA256:DHE-DSS-AES256-SHA:DHE-RSA-AES256-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:AES:CAMELLIA:DES-CBC3-SHA:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!MD5:!PSK:!aECDH:!EDH-DSS-DES-CBC3-SHA:!EDH-RSA-DES-CBC3-SHA:!KRB5-DES-CBC3-SHA';
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:50m;
    ssl_stapling on;
    ssl_stapling_verify on;
    add_header Strict-Transport-Security max-age=15768000;

    ...

    location @proxy {
       ...
    }
}
```

上面的配置是对Nginx的TLS的相对严格的设置。这里的一些设置不是必须的，但可以增强安全性。
