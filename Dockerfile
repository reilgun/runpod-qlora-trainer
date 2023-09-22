FROM runpod/pytorch:2.0.1-py3.10-cuda11.8.0-devel

# Set workspace directory
WORKDIR /workspace

# Install AWS CLI and zip
RUN apt-get update && \
    apt-get install -y awscli zip

# Install ninja and flash_attn with pip
RUN pip install ninja
RUN pip install flash_attn

# Clone the qlora repository
RUN git clone https://github.com/reilgun/qlora.git

# Change to qlora directory and install requirements
WORKDIR /workspace/qlora
RUN pip install -r requirements.txt

# Copy the entrypoint script into the image
COPY entrypoint.sh /workspace/qlora/entrypoint.sh

# Make the entrypoint script executable
RUN chmod +x /workspace/qlora/entrypoint.sh

# Set the entrypoint
ENTRYPOINT ["/workspace/qlora/entrypoint.sh"]
